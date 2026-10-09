import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthSelectionPage extends StatelessWidget {
  const AuthSelectionPage({super.key});

  static const Color _primary = Color(0xFF8D85D6);
  static const Color _textDark = Color(0xFF2B2A33);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'English Study',
                style: TextStyle(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w900, // 더 두껍게
                  color: _textDark,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                '나만의 영어 학습 메이트',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 60.h),
              _buildPrimaryButton(
                context,
                title: '로그인',
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
              SizedBox(height: 16.h),
              _buildOutlinedButton(
                context,
                title: '회원가입',
                onPressed: () => Navigator.pushNamed(context, '/signup'),
              ),
              SizedBox(height: 16.h),
              _buildGhostButton(
                context,
                title: '게스트로 시작하기',
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signInAnonymously();
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/level_select');
                  } on FirebaseAuthException catch (e) {
                    if (!context.mounted) return;
                    String message = '게스트 로그인에 실패했습니다: ${e.message}';
                    if (e.code == 'operation-not-allowed') {
                      message = '익명 로그인이 비활성화되어 있습니다. Firebase 콘솔에서 활성화해주세요.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('예상치 못한 오류가 발생했습니다.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, {required String title, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [Color(0xFFA99FEE), Color(0xFF8D85D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context, {required String title, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: _primary),
        ),
      ),
    );
  }

  Widget _buildGhostButton(BuildContext context, {required String title, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: TextButton(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}