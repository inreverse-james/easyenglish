import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easyenglish/theme/app_theme.dart';
import 'package:easyenglish/services/auth_service.dart';
import 'package:easyenglish/services/nickname_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  final NicknameService _nicknameService = NicknameService();

  // 아바타 선택 (-1: 구글 프로필 사진 사용)
  int _selectedAvatarIndex = 0;
  bool _isLoaded = false;
  final List<String> _defaultAvatars =
      List.generate(10, (i) => 'assets/avatars/avatar${i + 1}.png');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('selectedAvatarIndex') ?? 0;
      if (!mounted) return;
      setState(() {
        _selectedAvatarIndex =
            (saved >= -1 && saved < _defaultAvatars.length) ? saved : 0;
        _isLoaded = true;
      });
    } catch (e) {
      debugPrint('SettingsPage: 설정 로딩 실패: $e');
      if (!mounted) return;
      setState(() => _isLoaded = true);
    }
  }

  Future<void> _saveAvatarIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedAvatarIndex', _selectedAvatarIndex);
  }

  // ------------------------------ 표시용 값 ------------------------------
  String _displayName(User user) {
    final dn = user.displayName;
    if (dn != null && dn.isNotEmpty) return dn;
    if (user.isAnonymous) return '게스트 사용자';
    final em = user.email;
    if (em != null && em.isNotEmpty) return em.split('@')[0];
    return '사용자';
  }

  String _accountLabel(User user) {
    if (user.isAnonymous) return '게스트 계정';
    final em = user.email;
    if (em != null && em.isNotEmpty) return em;
    return 'Google 계정';
  }

  ImageProvider _profileImage(User user) {
    final photoUrl = user.photoURL;
    if (_selectedAvatarIndex == -1 && photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    final idx = (_selectedAvatarIndex >= 0 &&
            _selectedAvatarIndex < _defaultAvatars.length)
        ? _selectedAvatarIndex
        : 0;
    return AssetImage(_defaultAvatars[idx]);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------ 닉네임 ------------------------------
  void _showNicknameDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (_) => _NicknameEditDialog(
        user: user,
        nicknameService: _nicknameService,
        authService: _authService,
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // ------------------------------ 아바타 ------------------------------
  void _showAvatarSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final photoUrl = user.photoURL;
    final hasGooglePhoto = photoUrl != null && photoUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '아바타 선택',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _defaultAvatars.length + (hasGooglePhoto ? 1 : 0),
                    itemBuilder: (_, index) {
                      final isGoogleItem = hasGooglePhoto && index == 0;
                      final avatarIndex = hasGooglePhoto ? index - 1 : index;
                      final selected = isGoogleItem
                          ? _selectedAvatarIndex == -1
                          : _selectedAvatarIndex == avatarIndex;

                      return GestureDetector(
                        onTap: () async {
                          setState(() => _selectedAvatarIndex =
                              isGoogleItem ? -1 : avatarIndex);
                          await _saveAvatarIndex();

                          if (!isGoogleItem) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({
                              'avatar': _defaultAvatars[avatarIndex],
                            }, SetOptions(merge: true));
                          }

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: AppColors.background,
                            backgroundImage: isGoogleItem
                                ? NetworkImage(photoUrl!) as ImageProvider
                                : AssetImage(_defaultAvatars[avatarIndex]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------ 로그인 / 연동 ------------------------------
  Future<void> _signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();

      String message;
      switch (result.type) {
        case GoogleSignInResultType.linked:
          message = 'Google 계정과 연동되었어요. 기존 데이터는 유지됩니다.';
          break;
        case GoogleSignInResultType.switchedToExistingAccount:
          message = '이미 사용 중인 Google 계정이라 해당 계정으로 로그인했어요.';
          break;
        case GoogleSignInResultType.signedIn:
          message = 'Google 계정으로 로그인했어요.';
          break;
      }
      _snack(message);
      if (mounted) setState(() {});
    } on FirebaseAuthException catch (e) {
      _snack('로그인에 실패했어요. ${e.message ?? e.code}');
    } catch (e) {
      _snack('알 수 없는 오류가 발생했어요. $e');
    }
  }

  // ------------------------------ 로그아웃 ------------------------------
  Future<void> _onLogoutTap(User user) async {
    // 게스트는 로그아웃하면 그 계정으로 다시 돌아올 방법이 없으므로 한 번 더 확인합니다.
    if (user.isAnonymous) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('로그아웃'),
          content: const Text(
            '게스트 계정은 로그아웃하면 다시 불러올 수 없어요.\n'
            '기록을 유지하려면 먼저 Google 계정과 연동해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('그래도 로그아웃'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _signOut();
  }

  Future<void> _signOut() async {
    // await 이후에는 context를 안전하게 쓸 수 없으므로 미리 가져옵니다.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.signOut();
      // 설정 화면이 홈 위에 쌓여 있으므로, 첫 화면(= 로그인 상태에 따라 바뀌는 화면)까지 돌아갑니다.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('로그아웃했어요.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('로그아웃에 실패했어요. $e')));
    }
  }

  // ------------------------------ 회원 탈퇴 ------------------------------
  void _showDeleteAccountDialog(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: Text(
          user.isAnonymous
              ? '탈퇴하면 게스트 계정의 데이터(닉네임 등)가 모두 삭제되며 '
                  '복구할 수 없어요.\n계속할까요?'
              : '탈퇴하면 계정과 관련된 모든 데이터(닉네임 등)가 삭제되며 '
                  '복구할 수 없어요.\n계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    void finish() {
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴가 완료되었어요.')));
    }

    try {
      await _authService.deleteAccount();
      finish();
    } on ReauthenticationRequiredException {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        // 구글 계정: 다시 로그인(재인증)한 뒤 한 번 더 시도
        try {
          await _authService.reauthenticateWithGoogle();
          await _authService.deleteAccount();
          finish();
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('탈퇴에 실패했어요. $e')));
        }
      } else {
        // 게스트: 재인증 방법이 없습니다. 서버 데이터는 이미 삭제되었으므로
        // 로그아웃으로 마무리합니다.
        try {
          await _authService.signOut();
          finish();
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('탈퇴에 실패했어요. $e')));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('탈퇴에 실패했어요. $e')));
    }
  }

  // ------------------------------ UI ------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 로그아웃/탈퇴 직후 잠깐 user가 null일 수 있으므로 빈 화면으로 둡니다.
    if (!_isLoaded || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: _isLoaded
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final isGuest = user.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          // 프로필 헤더
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showAvatarSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44.r,
                        backgroundColor: AppColors.separator,
                        backgroundImage: _profileImage(user),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.background, width: 2),
                          ),
                          child: Icon(Icons.edit,
                              size: 13.sp, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  _displayName(user),
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _accountLabel(user),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28.h),

          // 프로필 / 계정
          _SectionCard(
            children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                title: '닉네임 변경',
                value: _displayName(user),
                onTap: _showNicknameDialog,
              ),
              _SettingsRow(
                icon: Icons.account_circle_outlined,
                title: '아바타 변경',
                onTap: _showAvatarSheet,
              ),
              _SettingsRow(
                leading: Image.asset(
                  'assets/images/google_logo.png',
                  width: 22.w,
                  height: 22.w,
                  errorBuilder: (_, __, ___) => Icon(Icons.login,
                      size: 22.sp, color: AppColors.primary),
                ),
                title: isGuest ? 'Google 계정과 연동하기' : '다른 Google 계정으로 전환',
                onTap: _signInWithGoogle,
              ),
            ],
          ),
          if (isGuest)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Text(
                '게스트 계정은 로그아웃하면 다시 불러올 수 없어요. '
                'Google 계정과 연동하면 데이터를 안전하게 지킬 수 있어요.',
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          SizedBox(height: 24.h),

          // 로그아웃 / 탈퇴
          _SectionCard(
            children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                destructive: true,
                showChevron: false,
                onTap: () => _onLogoutTap(user),
              ),
              _SettingsRow(
                icon: Icons.person_remove_outlined,
                title: '회원 탈퇴',
                destructive: true,
                showChevron: false,
                onTap: () => _showDeleteAccountDialog(user),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 흰 카드 안에 행들이 얇은 선으로 구분되어 나열되는 묶음
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Padding(
          padding: EdgeInsets.only(left: 52.w),
          child: const Divider(),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    this.leading,
    required this.title,
    this.value,
    this.destructive = false,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? value;
  final bool destructive;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            SizedBox(
              width: 24.w,
              child: leading ??
                  Icon(
                    icon,
                    size: 22.sp,
                    color: destructive ? AppColors.danger : AppColors.primary,
                  ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16.sp, color: color),
              ),
            ),
            if (value != null) ...[
              SizedBox(width: 8.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 120.w),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  size: 22.sp, color: const Color(0xFFC7C7CC)),
          ],
        ),
      ),
    );
  }
}

/// 닉네임 편집 다이얼로그.
/// 타이핑 중(디바운스 500ms) NicknameService.checkAvailability로 실시간 검증하고,
/// 저장 시에는 NicknameService.changeNickname으로 최종(형식/금지어/중복) 검증 + 저장한다.
class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({
    required this.user,
    required this.nicknameService,
    required this.authService,
    required this.onSaved,
  });

  final User user;
  final NicknameService nicknameService;
  final AuthService authService;
  final VoidCallback onSaved;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;

  bool _isChecking = false;
  bool _isSaving = false;
  bool? _isAvailable; // null: 확인 전, true: 사용 가능, false: 사용 불가
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

    if (trimmed == (widget.user.displayName ?? '')) {
      setState(() {
        _isAvailable = true;
        _checkMessage = '현재 사용 중인 닉네임이에요.';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isChecking = true);
      final result = await widget.nicknameService.checkAvailability(trimmed);

      // 응답을 기다리는 동안 입력이 바뀌었다면 결과를 버립니다.
      if (!mounted || _controller.text.trim() != trimmed) return;

      setState(() {
        _isChecking = false;
        _isAvailable = result.available;
        _checkMessage = result.available ? '사용 가능한 닉네임이에요.' : result.message;
      });
    });
  }

  Future<void> _save() async {
    final newNickname = _controller.text.trim();
    setState(() => _isSaving = true);
    try {
      // 실시간 체크는 참고용이고, 최종 확정(중복 재확인 포함)은 트랜잭션이 처리합니다.
      await widget.nicknameService.changeNickname(
        uid: widget.user.uid,
        newNickname: newNickname,
      );
      await widget.authService.updateDisplayName(newNickname);
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임을 변경했어요.')),
        );
      }
    } on NicknameException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('변경에 실패했어요. $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (_isAvailable == true) {
      statusColor = const Color(0xFF248A3D);
    } else if (_isAvailable == false) {
      statusColor = AppColors.danger;
    } else {
      statusColor = AppColors.textSecondary;
    }

    // 사용 불가로 확인된 경우에만 저장을 막습니다. (최종 검증은 서버에서)
    final canSave = !_isSaving && _isAvailable != false;

    return AlertDialog(
      title: const Text('닉네임 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onNicknameChanged,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '사용할 닉네임을 입력하세요',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: _isChecking
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            width: double.infinity,
            child: Text(
              _checkMessage ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: statusColor),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
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
