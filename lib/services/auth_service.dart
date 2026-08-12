import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easyenglish/services/ranking_service.dart';
import 'package:easyenglish/utils/nickname_validator.dart';

/// 계정 삭제 시, 보안을 위해 재로그인이 필요한 경우 던지는 예외.
/// UI에서 이 예외를 잡아 재인증 후 삭제를 다시 시도하도록 안내한다.
class ReauthenticationRequiredException implements Exception {
  const ReauthenticationRequiredException();
}

/// 로그인 결과를 페이지에 알려주기 위한 상태
enum GoogleSignInResultType {
  signedIn, // 새로 로그인됨
  linked, // 게스트 계정이 구글 계정과 연동됨
  switchedToExistingAccount, // 이미 존재하는 계정이라 그 계정으로 전환됨
}

class GoogleSignInResult {
  final GoogleSignInResultType type;
  GoogleSignInResult(this.type);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RankingService _rankingService = RankingService();

  User? get currentUser => _auth.currentUser;

  bool get isGuest => currentUser != null && currentUser!.isAnonymous;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 앱 시작 시 한 번 호출 (main.dart에서)
  Future<void> initialize() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize();
    }
  }

  /// 게스트로 시작하기 (익명 로그인)
  Future<User?> signInAsGuest() async {
    final userCredential = await _auth.signInAnonymously();
    return userCredential.user;
  }

  /// 구글 로그인 / 게스트 계정과 연동
  Future<GoogleSignInResult> signInWithGoogle() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    final currentUser = _auth.currentUser;

    Future<void> doLink() async {
      if (kIsWeb) {
        await currentUser!.linkWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final credential = GoogleAuthProvider.credential(
          idToken: googleUser.authentication.idToken,
        );
        await currentUser!.linkWithCredential(credential);
      }
    }

    Future<void> doSignIn() async {
      if (kIsWeb) {
        await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final credential = GoogleAuthProvider.credential(
          idToken: googleUser.authentication.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    }

    GoogleSignInResultType resultType;

    if (currentUser != null && currentUser.isAnonymous) {
      try {
        await doLink();
        resultType = GoogleSignInResultType.linked;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await doSignIn();
          resultType = GoogleSignInResultType.switchedToExistingAccount;
        } else {
          rethrow;
        }
      }
    } else {
      await doSignIn();
      resultType = GoogleSignInResultType.signedIn;
    }

    await _rankingService.syncUserProfile();

    return GoogleSignInResult(resultType);
  }

  /// 닉네임 변경
  Future<void> updateDisplayName(String newNickname) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(newNickname);
    await user.reload();
    await _rankingService.syncUserProfile();
  }

  /// 구글 계정으로 재인증 (탈퇴 등 민감한 작업 전, 세션이 오래돼서
  /// requires-recent-login 에러가 났을 때 다시 호출)
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final googleProvider = GoogleAuthProvider();
    if (kIsWeb) {
      await user.reauthenticateWithPopup(googleProvider);
    } else {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  /// 회원 탈퇴.
  /// - Firestore에 남아있는 사용자 관련 데이터(users, nicknames, rankings)를 먼저 지우고
  /// - 그다음 Firebase Auth 계정 자체를 삭제한다.
  /// - 세션이 오래돼서 삭제가 거부되면 [ReauthenticationRequiredException]을 던진다.
  ///   -> 구글 계정이면 [reauthenticateWithGoogle] 호출 후 이 함수를 다시 부르면 됨.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final currentNickname = user.displayName;

    // 1) Firestore 데이터 정리 (users, nicknames, rankings)
    final batch = _firestore.batch();

    batch.delete(_firestore.collection('users').doc(uid));

    if (currentNickname != null && currentNickname.isNotEmpty) {
      final normalized = NicknameValidator.normalize(currentNickname);
      batch.delete(_firestore.collection('nicknames').doc(normalized));
    }

    final rankingsSnap = await _firestore
        .collection('rankings')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in rankingsSnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // 2) Firebase Auth 계정 삭제
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const ReauthenticationRequiredException();
      }
      rethrow;
    }

    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }
}