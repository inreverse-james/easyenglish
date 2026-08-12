import 'dart:math';

import '../services/nickname_service.dart';

/// 게스트(익명) 사용자를 위한 랜덤 닉네임 생성기.
/// 예: "즐거운다람쥐42", "용감한사자7"
class GuestNameGenerator {
  static final List<String> _adjectives = [
    '즐거운', '용감한', '똑똑한', '재빠른', '느긋한',
    '상냥한', '씩씩한', '엉뚱한', '차분한', '활기찬',
    '신나는', '조용한', '든든한', '유쾌한', '당당한',
  ];

  static final List<String> _animals = [
    '다람쥐', '사자', '토끼', '여우', '고양이',
    '펭귄', '부엉이', '너구리', '수달', '판다',
    '호랑이', '코알라', '햄스터', '고슴도치', '오리',
  ];

  static final Random _random = Random();

  /// 새 랜덤 닉네임 후보 생성 (매번 호출할 때마다 조합이 달라짐).
  /// 형용사(3글자) + 동물(2~4글자) + 숫자(2자리) 조합으로, 최대 9글자라
  /// NicknameValidator의 2~10글자 규칙 안에 항상 들어온다.
  /// 주의: 이 함수만으로는 중복 여부를 알 수 없다 - 실제 사용 전엔 아래
  /// [generateAndReserve]로 NicknameService를 통해 확정해야 한다.
  static String generate() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final animal = _animals[_random.nextInt(_animals.length)];
    final number = _random.nextInt(90) + 10; // 10~99
    return '$adjective$animal$number';
  }

  /// [generate]로 후보를 만들어서 NicknameService에 실제로 확정 저장까지 한다.
  /// 드물게 후보가 이미 사용 중이면 자동으로 재시도한다.
  static Future<String> generateAndReserve({
    required NicknameService nicknameService,
    required String uid,
    int maxAttempts = 5,
  }) async {
    NicknameException? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = generate();
      try {
        await nicknameService.changeNickname(uid: uid, newNickname: candidate);
        return candidate;
      } on NicknameException catch (e) {
        // 이미 사용 중인 닉네임이었다면 다음 후보로 재시도.
        // (형식/금지어 문제는 생성 로직상 발생하지 않지만 혹시 몰라 기록만 해둔다)
        lastError = e;
      }
    }

    throw lastError ?? NicknameException('게스트 닉네임을 생성하지 못했습니다.');
  }
}