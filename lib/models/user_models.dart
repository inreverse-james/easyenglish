class UserModel {
  final String uid;
  final String? email;
  final String nickname;
  final String? phoneNumber;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final UserAuthProvider authProvider; // 변경됨
  final bool isAnonymous;

  UserModel({
    required this.uid,
    this.email,
    required this.nickname,
    this.phoneNumber,
    this.photoURL,
    required this.createdAt,
    this.lastLoginAt,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    required this.authProvider,
    this.isAnonymous = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      nickname: json['nickname'] ?? '익명사용자',
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastLoginAt'])
          : null,
      isEmailVerified: json['isEmailVerified'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      authProvider: UserAuthProvider.values.firstWhere(
        (e) => e.name == json['authProvider'],
        orElse: () => UserAuthProvider.email,
      ),
      isAnonymous: json['isAnonymous'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'authProvider': authProvider.name,
      'isAnonymous': isAnonymous,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? nickname,
    String? phoneNumber,
    String? photoURL,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    UserAuthProvider? authProvider,
    bool? isAnonymous,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      authProvider: authProvider ?? this.authProvider,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, nickname: $nickname, authProvider: ${authProvider.name})';
  }

  static bool isValidNickname(String nickname) {
    final regex = RegExp(r'^[가-힣a-zA-Z0-9]{2,20}$');
    return regex.hasMatch(nickname);
  }

  String get displayName {
    if (nickname.isNotEmpty && nickname != '익명사용자') {
      return nickname;
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@')[0];
    }
    return '사용자';
  }

  bool get isProfileComplete {
    return nickname.isNotEmpty &&
        nickname != '익명사용자' &&
        (email != null || phoneNumber != null);
  }
}

// ✅ 이름 변경됨
enum UserAuthProvider {
  email,
  google,
  phone,
  anonymous,
}

extension UserAuthProviderExtension on UserAuthProvider {
  String get displayName {
    switch (this) {
      case UserAuthProvider.email:
        return '이메일';
      case UserAuthProvider.google:
        return '구글';
      case UserAuthProvider.phone:
        return '전화번호';
      case UserAuthProvider.anonymous:
        return '게스트';
    }
  }

  String get icon {
    switch (this) {
      case UserAuthProvider.email:
        return '📧';
      case UserAuthProvider.google:
        return '🎯';
      case UserAuthProvider.phone:
        return '📱';
      case UserAuthProvider.anonymous:
        return '👤';
    }
  }
}
