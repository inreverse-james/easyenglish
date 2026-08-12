import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easyenglish/utils/nickname_validator.dart';

/// 닉네임 관련 에러 (UI에서 그대로 SnackBar 등에 띄울 수 있도록 message를 사람이 읽을 문장으로 둠)
class NicknameException implements Exception {
  final String message;
  NicknameException(this.message);

  @override
  String toString() => message;
}

class NicknameCheckResult {
  final bool available;
  final String? message; // available == false일 때 사유
  const NicknameCheckResult({required this.available, this.message});
}

/// Firestore 구조
/// - nicknames/{normalizedNickname} : { uid, displayName, createdAt/updatedAt }
///     -> 닉네임 자체를 문서 ID로 써서, 트랜잭션 안에서 "존재 여부 확인 + 생성"을
///        원자적으로 처리한다 (동시에 같은 닉네임을 시도해도 하나만 성공).
/// - bannedWords/{word} : 금지어 컬렉션. Firebase 콘솔에서 문서를 추가/삭제하면 바로 반영됨.
/// - users/{uid}.nickname : 현재 사용자의 표시용 닉네임.
class NicknameService {
  NicknameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // bannedWords 컬렉션 안에 문서 1개(_bannedWordsDocId)를 두고,
  // 그 문서의 words 배열 필드에 금지어를 전부 넣어서 관리한다.
  // -> 콘솔에서 문서를 하나하나 만들 필요 없이, 배열 필드에 항목만 추가/삭제하면 됨.
  static const _bannedWordsCollection = 'bannedWords';
  static const _bannedWordsDocId = 'list';
  static const _bannedWordsField = 'words';
  static const _nicknamesCollection = 'nicknames';
  static const _usersCollection = 'users';

  // 금지어는 자주 바뀌는 데이터가 아니라서, 매 검증마다 다시 읽지 않고
  // 짧은 시간(5분) 동안은 메모리에 캐시해서 재사용한다.
  List<String>? _bannedWordsCache;
  DateTime? _bannedWordsFetchedAt;
  static const _bannedWordsCacheTtl = Duration(minutes: 5);

  Future<List<String>> _getBannedWords({bool forceRefresh = false}) async {
    final isCacheValid = _bannedWordsCache != null &&
        _bannedWordsFetchedAt != null &&
        DateTime.now().difference(_bannedWordsFetchedAt!) < _bannedWordsCacheTtl;

    if (!forceRefresh && isCacheValid) {
      return _bannedWordsCache!;
    }

    final doc = await _firestore
        .collection(_bannedWordsCollection)
        .doc(_bannedWordsDocId)
        .get();

    final rawList = doc.data()?[_bannedWordsField] as List<dynamic>? ?? const [];
    final words = rawList.map((w) => w.toString().toLowerCase()).toList();

    _bannedWordsCache = words;
    _bannedWordsFetchedAt = DateTime.now();
    return words;
  }

  /// 닉네임 안에 금지어가 "포함"되어 있는지 확인 (완전 일치가 아니라 부분 문자열 검사)
  bool _containsBannedWord(String normalizedNickname, List<String> bannedWords) {
    for (final word in bannedWords) {
      if (word.isEmpty) continue;
      if (normalizedNickname.contains(word)) return true;
    }
    return false;
  }

  /// 타이핑 중 실시간 피드백용. 실제로 예약(선점)하지는 않으므로
  /// 이 체크 이후에도 다른 사람이 먼저 가져갈 수 있다 - 최종 확정은 [changeNickname]에서 트랜잭션으로 처리.
  Future<NicknameCheckResult> checkAvailability(String nickname) async {
    final formatError = NicknameValidator.validateFormat(nickname);
    if (formatError != null) {
      return NicknameCheckResult(available: false, message: formatError);
    }

    final normalized = NicknameValidator.normalize(nickname);

    final bannedWords = await _getBannedWords();
    if (_containsBannedWord(normalized, bannedWords)) {
      return const NicknameCheckResult(available: false, message: '사용할 수 없는 닉네임입니다.');
    }

    final doc = await _firestore.collection(_nicknamesCollection).doc(normalized).get();
    if (doc.exists) {
      return const NicknameCheckResult(available: false, message: '이미 사용 중인 닉네임입니다.');
    }

    return const NicknameCheckResult(available: true);
  }

  /// 닉네임을 확정 저장한다. 최초 설정/변경 모두 이 함수 하나로 처리된다.
  /// - 형식 검증 -> 금지어 검증 -> 트랜잭션(중복 체크 + 저장 + 이전 닉네임 반납)
  /// - 실패 시 [NicknameException]을 던진다.
  Future<void> changeNickname({required String uid, required String newNickname}) async {
    final formatError = NicknameValidator.validateFormat(newNickname);
    if (formatError != null) {
      throw NicknameException(formatError);
    }

    final trimmedNew = newNickname.trim();
    final normalizedNew = NicknameValidator.normalize(trimmedNew);

    final bannedWords = await _getBannedWords();
    if (_containsBannedWord(normalizedNew, bannedWords)) {
      throw NicknameException('사용할 수 없는 닉네임입니다.');
    }

    final userRef = _firestore.collection(_usersCollection).doc(uid);
    final newNicknameRef = _firestore.collection(_nicknamesCollection).doc(normalizedNew);

    await _firestore.runTransaction((tx) async {
      // Firestore 트랜잭션 규칙: 모든 get()은 set/update/delete보다 먼저 실행되어야 한다.
      final userSnap = await tx.get(userRef);
      final currentNickname = userSnap.data()?['nickname'] as String?;
      final currentNormalized =
          currentNickname != null ? NicknameValidator.normalize(currentNickname) : null;

      // 대소문자만 바뀌는 등 정규화 기준으로 "같은" 닉네임이면 중복 체크 없이 표시값만 갱신
      if (currentNormalized == normalizedNew) {
        tx.set(
          newNicknameRef,
          {
            'uid': uid,
            'displayName': trimmedNew,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        tx.update(userRef, {'nickname': trimmedNew});
        return;
      }

      final newNicknameSnap = await tx.get(newNicknameRef);
      if (newNicknameSnap.exists) {
        throw NicknameException('이미 사용 중인 닉네임입니다.');
      }

      tx.set(newNicknameRef, {
        'uid': uid,
        'displayName': trimmedNew,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 이전 닉네임 문서를 지워서 즉시 다른 사람이 쓸 수 있도록 반납한다.
      if (currentNormalized != null) {
        final oldRef = _firestore.collection(_nicknamesCollection).doc(currentNormalized);
        tx.delete(oldRef);
      }

      tx.update(userRef, {'nickname': trimmedNew});
    });
  }
}