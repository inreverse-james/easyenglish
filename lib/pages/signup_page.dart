import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      _showErrorMessage('게스트 모드 진입 실패: ${e.code} / ${e.message}');
    } catch (e) {
      _showErrorMessage('게스트 모드 진입 실패(기타): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showErrorMessage('구글 로그인 실패: ${e.message}');
    } catch (e) {
      _showErrorMessage('구글 로그인 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('시작하기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '환영합니다!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2B2A33)), // 폰트 크기 및 두께 강화
              ),
              const SizedBox(height: 8),
              const Text(
                'Google 계정으로 시작하거나 게스트로 체험해보세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 22,
                      width: 22,
                    ),
                    label: const Text(
                      'Google 계정으로 계속하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), // 완전 둥근(999) 대신 약간 둥근(16) 모서리로 모던하게
                      ),
                      elevation: 2, // 약간의 그림자 추가
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('또는'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8D85D6),
                      side: const BorderSide(color: Color(0xFF8D85D6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      '게스트로 시작하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '게스트로 시작해도 나중에 설정 화면에서\nGoogle 계정으로 전환할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}