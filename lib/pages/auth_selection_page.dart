import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthSelectionPage extends StatelessWidget {
  const AuthSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'English Study',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('로그인'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text('회원가입'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
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
              child: const Text('게스트로 시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}
