/// 닉네임 "형식" 검증만 담당하는 유틸리티.
/// - Firestore 통신(중복 체크, 금지어 체크)은 여기서 하지 않는다.
/// - 순수 함수라 유닛테스트하기 쉽고, 입력창에서 실시간(타이핑 중) 검증에도 바로 쓸 수 있다.
class NicknameValidator {
  static const int minLength = 2;
  static const int maxLength = 10;

  // 한글, 영문, 숫자만 허용 (공백/특수문자 불가).
  // 필요하면 이 정규식만 바꾸면 됨.
  static final RegExp _allowedPattern = RegExp(r'^[가-힣a-zA-Z0-9]+$');

  /// 형식이 유효하면 null, 문제가 있으면 에러 메시지를 반환한다.
  static String? validateFormat(String nickname) {
    final trimmed = nickname.trim();

    if (trimmed.isEmpty) {
      return '닉네임을 입력해주세요.';
    }

    // 공백 포함 여부는 trim 전 원본으로 체크해야
    // "가 나"처럼 중간에 공백이 있는 경우도 잡아낼 수 있다.
    if (nickname.contains(RegExp(r'\s'))) {
      return '닉네임에는 공백을 사용할 수 없습니다.';
    }

    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return '닉네임은 $minLength~$maxLength자로 입력해주세요.';
    }

    if (!_allowedPattern.hasMatch(trimmed)) {
      return '닉네임은 한글, 영문, 숫자만 사용할 수 있습니다.';
    }

    return null;
  }

  static bool isValidFormat(String nickname) => validateFormat(nickname) == null;

  /// 중복/금지어 비교에 쓰는 정규화 키.
  /// 대소문자 구분 없이 비교해야 하므로 소문자로 통일한다.
  /// (한글은 대소문자가 없으므로 영문만 영향을 받음)
  static String normalize(String nickname) => nickname.trim().toLowerCase();
}