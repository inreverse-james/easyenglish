import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easyenglish/services/auth_service.dart';
import 'package:easyenglish/services/nickname_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required String userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 새 디자인 컨셉 색상 (소프트 라벤더 톤)
  static const Color _primary = Color(0xFF8D85D6);
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);

  final AuthService _authService = AuthService();
  final NicknameService _nicknameService = NicknameService();

  // 프로필 정보
  String _organization = '';

  // 아바타 선택
  int _selectedAvatarIndex = -1;
  final List<String> _defaultAvatars = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
    'assets/avatars/avatar6.png',
    'assets/avatars/avatar7.png',
    'assets/avatars/avatar8.png',
    'assets/avatars/avatar9.png',
    'assets/avatars/avatar10.png',
  ];

  // 비동기 작업의 상태를 추적하기 위한 Future 객체
  late Future<void> _loadSettingsFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('SettingsPage: initState() 호출');
    _loadSettingsFuture = _loadSettings();
  }

  Future<void> _loadSettings() async {
    debugPrint('SettingsPage: _loadSettings() 시작');
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedAvatarIndex = prefs.getInt('selectedAvatarIndex') ?? 0;
        _organization = prefs.getString('organization') ?? '';
      });
      debugPrint('SettingsPage: _loadSettings() 완료');
    } catch (e) {
      debugPrint('SettingsPage: _loadSettings() 실패: $e');
      rethrow;
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedAvatarIndex', _selectedAvatarIndex);
    await prefs.setString('organization', _organization);
  }

  String _getDisplayName(User? user) {
    if (user == null) return "게스트";
    final dn = user.displayName;
    if (dn != null && dn.isNotEmpty) return dn;
    if (user.isAnonymous) return "게스트 사용자"; // 닉네임이 아직 없는 예외적인 경우 대비
    final em = user.email;
    if (em != null && em.isNotEmpty) return em.split('@')[0];
    return "사용자";
  }

  String _getUserId(User? user) {
    if (user == null) return "로그인 정보 없음";

    if (user.isAnonymous) {
      return "게스트 사용자";
    }

    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }

    return "사용자";
  }

  // 프로필 편집 다이얼로그
  void _showProfileEditDialog() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _NicknameEditDialog(
        user: user,
        nicknameService: _nicknameService,
        authService: _authService,
        primary: _primary,
        onSaved: () {
          setState(() {});
          _saveSettings();
        },
      ),
    );
  }

  // 게스트로 시작하기
  Future<void> _signInAnonymously() async {
    try {
      await _authService.signInAsGuest();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게스트로 로그인했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게스트 로그인 실패: $e')),
        );
      }
    }
  }

  // 구글 로그인 / 계정 연동
  // - 게스트(익명) 상태라면 기존 데이터를 유지한 채 구글 계정으로 "연동"합니다.
  // - 이미 구글 계정으로 로그인된 상태라면 다른 구글 계정으로 전환합니다.
  Future<void> _signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();

      String message;
      switch (result.type) {
        case GoogleSignInResultType.linked:
          message = 'Google 계정과 연동되었습니다! 기존 데이터는 유지됩니다.';
          break;
        case GoogleSignInResultType.switchedToExistingAccount:
          message = '이미 사용 중인 Google 계정이라 해당 계정으로 로그인했습니다.';
          break;
        case GoogleSignInResultType.signedIn:
          message = '구글 계정으로 로그인했습니다!';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알 수 없는 오류 발생: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  // 회원 탈퇴 확인 다이얼로그
  void _showDeleteAccountDialog(User user) {
    final bool isGuest = user.isAnonymous;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('회원 탈퇴'),
        content: Text(
          isGuest
              ? '탈퇴하면 지금까지의 게스트 기록(닉네임, 랭킹 등)이 모두 삭제되며 '
                  '복구할 수 없습니다.\n계속하시겠습니까?'
              : '탈퇴하면 계정과 관련된 모든 데이터(닉네임, 랭킹 등)가 삭제되며 '
                  '복구할 수 없습니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }

  // 실제 탈퇴 처리. 세션이 오래돼서 재인증이 필요하면(구글 계정에 한해)
  // 자동으로 재인증 후 한 번 더 시도한다.
  Future<void> _deleteAccount() async {
    try {
      await _authService.deleteAccount();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('탈퇴가 완료되었습니다.')),
        );
      }
    } on ReauthenticationRequiredException {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        // 구글 계정 -> 재인증 후 한 번 더 시도
        try {
          await _authService.reauthenticateWithGoogle();
          await _authService.deleteAccount();
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('탈퇴가 완료되었습니다.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('탈퇴 실패: $e')),
            );
          }
        }
      } else {
        // 게스트 계정은 재인증 수단이 없으므로 앱을 다시 시작해달라고 안내
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('보안을 위해 재로그인이 필요합니다. 앱을 껐다 켠 뒤 다시 시도해주세요.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 실패: $e')),
        );
      }
    }
  }

  // 아바타 선택 다이얼로그
  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('아바타 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _defaultAvatars.length +
                (FirebaseAuth.instance.currentUser?.photoURL != null ? 1 : 0),
            itemBuilder: (context, index) {
              final hasGooglePhoto =
                  FirebaseAuth.instance.currentUser?.photoURL != null;

              final avatarIndex = hasGooglePhoto ? index - 1 : index;

              return GestureDetector(
                onTap: () async {
                  // 구글 사진 선택
                  if (hasGooglePhoto && index == 0) {
                    setState(() {
                      _selectedAvatarIndex = avatarIndex;
                    });

                    await _saveSettings();

                    if (!mounted) return;

                    Navigator.of(this.context).pop();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('구글 프로필 사진으로 변경되었습니다.')),
                    );

                    return;
                  }

                  // 기본 아바타 선택
                  setState(() {
                    _selectedAvatarIndex = avatarIndex;
                  });

                  await _saveSettings();

                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .set({
                      'avatar': _defaultAvatars[avatarIndex],
                    }, SetOptions(merge: true));
                  }

                  if (!mounted) return;

                  Navigator.of(this.context).pop();

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('아바타가 변경되었습니다.')),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40.r,
                      backgroundImage: index == 0 &&
                              FirebaseAuth.instance.currentUser?.photoURL !=
                                  null
                          ? NetworkImage(
                              FirebaseAuth.instance.currentUser!.photoURL!)
                          : AssetImage(_defaultAvatars[avatarIndex]),
                    ),
                    if (_selectedAvatarIndex >= 0 &&
                        _selectedAvatarIndex == avatarIndex)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    if (_selectedAvatarIndex >= 0 &&
                        _selectedAvatarIndex == avatarIndex)
                      Icon(
                        Icons.check_circle,
                        color: _primary,
                        size: 24.sp,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadSettingsFuture,
      builder: (context, snapshot) {
        debugPrint(
            'FutureBuilder: ConnectionState -> ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7FB),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _primary),
                  SizedBox(height: 16.h),
                  Text('설정을 불러오는 중입니다...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7FB),
            appBar: AppBar(
              title: const Text('설정'),
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 60.sp),
                  SizedBox(height: 16.h),
                  Text(
                    '설정 로딩에 실패했습니다.',
                    style:
                        TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '오류: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final User? user = FirebaseAuth.instance.currentUser;
        final bool isGoogleUser = user != null && !user.isAnonymous;
        final String? photoUrl = user?.photoURL;

        ImageProvider profileImage;

        if (_selectedAvatarIndex == -1 &&
            photoUrl != null &&
            photoUrl.isNotEmpty) {
          profileImage = NetworkImage(photoUrl);
        } else {
          profileImage = AssetImage(_defaultAvatars[_selectedAvatarIndex]);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7FB),
          appBar: AppBar(
            title: const Text('설정',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                )),
            backgroundColor: Colors.transparent,
            foregroundColor: _textDark,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFEAFF),
                    Color(0xFFD8D1FF),
                    Color(0xFFC8C1FD),
                  ],
                ),
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.all(20.w),
            children: [
              SizedBox(height: 8.h),

              // 프로필 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarSelectionDialog,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44.r,
                            backgroundImage: profileImage,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Icon(
                                  Icons.edit,
                                  size: 14.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 닉네임 표시 및 편집 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDisplayName(user),
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        if (user != null) ...[
                          SizedBox(width: 6.w),
                          GestureDetector(
                            onTap: _showProfileEditDialog,
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: _primaryLight,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 14.sp,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 소속 정보 표시 (있을 경우에만)
                    if (_organization.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        _organization,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],

                    SizedBox(height: 6.h),

                    // 사용자 ID 표시
                    SelectableText(
                      _getUserId(user),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[400],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // 프로필 편집 버튼 (로그인된 사용자에게만 표시)
              if (user != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: _showProfileEditDialog,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('프로필 편집'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],

              // 로그인 관련 버튼들 (구글 / 게스트만 표시)
              if (user == null) ...[
                // 로그인되지 않은 상태
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _signInAnonymously,
                    icon: const Icon(Icons.person),
                    label: const Text('게스트로 시작하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Image.asset('assets/images/google_logo.png',
                        height: 20.sp, width: 20.sp),
                    label: const Text('Google 계정으로 로그인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
              ] else if (!isGoogleUser) ...[
                // 게스트로 로그인된 상태 -> 구글 계정 연동 유도
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Image.asset('assets/images/google_logo.png',
                        height: 20.sp, width: 20.sp),
                    label: const Text('Google 계정과 연동하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // 구글 계정으로 로그인된 상태
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Image.asset('assets/images/google_logo.png',
                        height: 20.sp, width: 20.sp),
                    label: const Text('다른 Google 계정으로 전환'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
              ],

              if (user != null) ...[
                SizedBox(height: 12.h),
                Center(
                  child: TextButton(
                    onPressed: () => _showDeleteAccountDialog(user),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[500],
                    ),
                    child: const Text(
                      '회원 탈퇴',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }
}

/// 프로필 편집 다이얼로그.
/// 타이핑 중(디바운스 500ms) NicknameService.checkAvailability로 실시간 검증하고,
/// 저장 시에는 NicknameService.changeNickname으로 최종(형식/금지어/중복) 검증 + 저장한다.
class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({
    required this.user,
    required this.nicknameService,
    required this.authService,
    required this.primary,
    required this.onSaved,
  });

  final User user;
  final NicknameService nicknameService;
  final AuthService authService;
  final Color primary;
  final VoidCallback onSaved;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;

  bool _isChecking = false;
  bool _isSaving = false;
  bool? _isAvailable; // null: 아직 확인 전, true: 사용 가능, false: 사용 불가
  String? _checkMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.displayName ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onNicknameChanged(String value) {
    _debounce?.cancel();

    final trimmed = value.trim();

    setState(() {
      _isAvailable = null;
      _checkMessage = null;
      _isChecking = false;
    });

    if (trimmed.isEmpty) return;

    // 지금 쓰고 있는 닉네임 그대로면 굳이 서버까지 안 물어봐도 됨
    if (trimmed == (widget.user.displayName ?? '')) {
      setState(() {
        _isAvailable = true;
        _checkMessage = '현재 사용 중인 닉네임입니다.';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isChecking = true);

      final result = await widget.nicknameService.checkAvailability(trimmed);

      // 응답이 오는 동안 유저가 텍스트를 더 바꿨을 수 있으니, 지금 텍스트랑 다르면 결과를 버린다.
      if (!mounted || _controller.text.trim() != trimmed) return;

      setState(() {
        _isChecking = false;
        _isAvailable = result.available;
        _checkMessage = result.available ? '사용 가능한 닉네임입니다.' : result.message;
      });
    });
  }

  Future<void> _save() async {
    final newNickname = _controller.text.trim();

    setState(() => _isSaving = true);
    try {
      // 실시간 체크는 참고용일 뿐이고, 실제 확정(중복 재확인 포함)은
      // 여기서 changeNickname 트랜잭션이 최종적으로 처리한다.
      await widget.nicknameService.changeNickname(
        uid: widget.user.uid,
        newNickname: newNickname,
      );

      // 화면 표시용 displayName도 함께 맞춰준다 (_getDisplayName이 이 값을 씀).
      await widget.authService.updateDisplayName(newNickname);
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
        );
      }
    } on NicknameException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 업데이트 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (_isAvailable == true) {
      statusColor = Colors.green[700]!;
    } else if (_isAvailable == false) {
      statusColor = Colors.red[700]!;
    } else {
      statusColor = Colors.grey[600]!;
    }

    // 명시적으로 사용 불가로 확인된 경우에만 저장을 막는다.
    // (아직 확인 전이거나 확인 중이어도 저장은 가능 - 최종 검증은 서버에서 함)
    final canSave = !_isSaving && _isAvailable != false;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: const Text('프로필 편집'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onNicknameChanged,
            decoration: InputDecoration(
              labelText: '닉네임',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              hintText: '사용할 닉네임을 입력하세요',
              suffixIcon: Padding(
                padding: EdgeInsets.all(14.w),
                child: SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: Visibility(
                    visible: _isChecking,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 20.h,
            width: double.infinity,
            child: Text(
              _checkMessage ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: statusColor),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          child: _isSaving
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}