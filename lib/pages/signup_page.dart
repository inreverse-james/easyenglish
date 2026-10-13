import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easyenglish/theme/app_theme.dart';
import 'package:easyenglish/utils/guest_name_generator.dart';
import 'package:easyenglish/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInAsGuest();
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await _authService.updateDisplayName(GuestNameGenerator.generate());
      }
    } on FirebaseAuthException catch (e) {
      _showMessage('게스트로 시작하지 못했어요. (${e.code})');
    } catch (e) {
      _showMessage('게스트로 시작하지 못했어요. $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showMessage('Google 로그인에 실패했어요. ${e.message ?? e.code}');
    } catch (e) {
      _showMessage('Google 로그인 중 오류가 발생했어요. $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // 앱 로고 영역
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33007AFF),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('📚', style: TextStyle(fontSize: 42)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Easy English',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '매일 조금씩, 꾸준히 영어 단어 공부',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),

              const Spacer(flex: 4),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: CircularProgressIndicator(),
                )
              else ...[
                // Google 버튼 (Google 브랜드 가이드: 흰 배경 + 얇은 테두리)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.separator),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/google_logo.png',
                          height: 20,
                          width: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.login, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Google로 계속하기',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _continueAsGuest,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '게스트로 시작하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '게스트로 시작해도 나중에 설정에서\nGoogle 계정으로 연동할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
