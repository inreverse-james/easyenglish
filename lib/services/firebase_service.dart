import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:easyenglish/models/user_models.dart';
import 'dart:developer';

class FirebaseService {
  // 싱글턴 인스턴스
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 전화번호 인증을 위한 변수들
  String? _verificationId;
  int? _resendToken;

  /// 이메일 + 비밀번호 회원가입
  Future<User?> signUpWithEmail(String email, String password,
      {String? nickname}) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // 사용자 프로필 데이터 저장
        await _createUserProfile(
          user,
          nickname: nickname ?? email.split('@')[0],
          authProvider: UserAuthProvider.email,
        );
      }

      return user;
    } on FirebaseAuthException catch (e) {
      log('Error signing up with email: ${e.code}');
      rethrow;
    }
  }

  /// 이메일 + 비밀번호 로그인
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _updateLastLogin(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      log('Error signing in with email: ${e.code}');
      rethrow;
    }
  }

  /// 구글 로그인
  Future<User?> signInWithGoogle({String? nickname}) async {
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // 새 사용자인지 확인
        final bool isNewUser =
            userCredential.additionalUserInfo?.isNewUser ?? false;

        if (isNewUser) {
          await _createUserProfile(
            user,
            nickname: nickname ??
                user.displayName ??
                user.email?.split('@')[0] ??
                '사용자',
            authProvider: UserAuthProvider.google,
          );
        } else {
          await _updateLastLogin(user.uid);
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      log('Error signing in with Google: ${e.code}');
      rethrow;
    } catch (e) {
      log('Unexpected error during Google sign-in: $e');
      rethrow;
    }
  }

  /// 전화번호로 인증 코드 발송
  Future<void> sendPhoneVerificationCode(
    String phoneNumber, {
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException error) verificationFailed,
    Function(PhoneAuthCredential credential)? verificationCompleted,
    Function(String verificationId)? codeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted ??
            (PhoneAuthCredential credential) async {
              // 자동 인증 완료 (Android에서만 발생)
              await _signInWithPhoneCredential(credential);
            },
        verificationFailed: verificationFailed,
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          codeSent(verificationId);
        },
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout ??
            (String verificationId) {
              log('Code auto retrieval timeout for verification ID: $verificationId');
            },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      log('Error sending phone verification code: $e');
      rethrow;
    }
  }

  /// 전화번호 인증 코드 검증 및 로그인/회원가입
  Future<User?> verifyPhoneCode(String smsCode, {String? nickname}) async {
    try {
      if (_verificationId == null) {
        throw Exception('인증 ID가 없습니다. 다시 인증을 요청해주세요.');
      }

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      return await _signInWithPhoneCredential(credential, nickname: nickname);
    } catch (e) {
      log('Error verifying phone code: $e');
      rethrow;
    }
  }

  /// PhoneAuthCredential로 로그인/회원가입
  Future<User?> _signInWithPhoneCredential(
    PhoneAuthCredential credential, {
    String? nickname,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final bool isNewUser =
            userCredential.additionalUserInfo?.isNewUser ?? false;

        if (isNewUser) {
          await _createUserProfile(
            user,
            nickname: nickname ?? '사용자${user.uid.substring(0, 6)}',
            authProvider: UserAuthProvider.phone,
          );
        } else {
          await _updateLastLogin(user.uid);
        }
      }

      return user;
    } catch (e) {
      log('Error signing in with phone credential: $e');
      rethrow;
    }
  }

  /// 익명(게스트) 로그인
  Future<User?> signInAnonymously() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedGuestUid = prefs.getString('guest_uid');

      // 1. 이미 저장된 게스트 UID가 있다면, 현재 Auth 상태 확인
      if (savedGuestUid != null) {
        // 이미 해당 UID로 로그인되어 있다면 그대로 반환
        if (_auth.currentUser?.uid == savedGuestUid) {
          return _auth.currentUser;
        }
      }

      // 2. 신규 익명 로그인 또는 세션 만료 시 로그인
      final UserCredential userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        log('Guest user signed in: ${user.uid}');

        // 3. 로컬에 UID 저장
        await prefs.setString('guest_uid', user.uid);

        // 4. Firestore에 이미 프로필이 있는지 확인 (중복 생성 방지)
        final docSnapshot = await _db.collection('users').doc(user.uid).get();
        if (!docSnapshot.exists) {
          await _createUserProfile(
            user,
            nickname: '게스트${user.uid.substring(0, 6)}',
            authProvider: UserAuthProvider.anonymous,
          );
        }
      }

      return user;
    } catch (e) {
      log('Error signing in anonymously: $e');
      return null;
    }
  }

  /// 사용자 프로필 생성 (Firestore에 저장)
  Future<void> _createUserProfile(
    User user, {
    required String nickname,
    required UserAuthProvider authProvider,
  }) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email,
      nickname: nickname,
      phoneNumber: user.phoneNumber,
      photoURL: user.photoURL,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      isEmailVerified: user.emailVerified,
      isPhoneVerified: user.phoneNumber != null,
      authProvider: authProvider,
      isAnonymous: user.isAnonymous,
    );

    await _db.collection('users').doc(user.uid).set(userModel.toJson());
    log('User profile created for ${user.uid}');
  }

  /// 마지막 로그인 시간 업데이트
  Future<void> _updateLastLogin(String userId) async {
    await _db.collection('users').doc(userId).update({
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 닉네임 업데이트
  Future<void> updateNickname(String userId, String nickname) async {
    if (!UserModel.isValidNickname(nickname)) {
      throw Exception('유효하지 않은 닉네임입니다. 2-20자의 한글, 영문, 숫자만 사용 가능합니다.');
    }

    await _db.collection('users').doc(userId).update({
      'nickname': nickname,
    });
    log('Nickname updated for user: $userId');
  }

  /// 사용자 프로필 정보 업데이트
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    await _db.collection('users').doc(userId).update(updates);
    log('User profile updated for: $userId');
  }

  /// 게스트 데이터를 정식 계정으로 이관
  Future<void> migrateGuestDataToUser(String newUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final guestUid = prefs.getString('guest_uid');

    if (guestUid != null) {
      final guestRef = _db.collection('users').doc(guestUid);
      final userRef = _db.collection('users').doc(newUserId);

      final guestDataSnapshot = await guestRef.get();
      if (guestDataSnapshot.exists) {
        final guestData = guestDataSnapshot.data();
        if (guestData != null) {
          await userRef.set(guestData, SetOptions(merge: true));
          log('Guest data migrated from $guestUid to $newUserId');
          await guestRef.delete();
          log('Guest data deleted for $guestUid');
        }
      }
      await prefs.remove('guest_uid');
    }
  }

  /// 사용자 데이터 저장 (기존 호환성을 위해 유지)
  Future<void> saveUserData(String userId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
    log('Data saved for user: $userId');
  }

  /// 사용자 데이터 실시간 가져오기 (UserModel로 변환)
  Stream<UserModel?> getUserModelStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    });
  }

  /// 사용자 데이터 실시간 가져오기 (기존 호환성을 위해 유지)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserData(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  /// 사용자 데이터 한 번만 가져오기
  Future<UserModel?> getUserModel(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromJson(doc.data()!);
    }
    return null;
  }

  /// 닉네임 중복 확인
  Future<bool> isNicknameAvailable(String nickname) async {
    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();

    return query.docs.isEmpty;
  }

  /// 현재 로그인된 사용자
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.signOut();

      // 전화번호 인증 관련 정보 초기화
      _verificationId = null;
      _resendToken = null;

      log('User signed out successfully');
    } catch (e) {
      log('Error signing out: $e');
    }
  }

  /// 전화번호 형식 검증 (한국 번호 기준)
  static bool isValidPhoneNumber(String phoneNumber) {
    // +82로 시작하는 한국 번호 또는 010으로 시작하는 번호
    final regex = RegExp(r'^(\+82|82)?[1-9]\d{7,9}$');
    return regex.hasMatch(phoneNumber.replaceAll(RegExp(r'[\s-]'), ''));
  }

  /// 전화번호를 국제 형식으로 변환 (+82)
  static String formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    if (cleaned.startsWith('010')) {
      return '+82${cleaned.substring(1)}';
    } else if (cleaned.startsWith('82')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('+82')) {
      return cleaned;
    }

    return cleaned;
  }
}
