import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/firebase_options.dart';
import 'package:easyenglish/theme/app_theme.dart';
import 'package:easyenglish/pages/signup_page.dart';
import 'package:easyenglish/pages/level_select_page.dart';
import 'package:easyenglish/services/auth_service.dart';
import 'package:easyenglish/services/ad_service.dart';
import 'package:easyenglish/services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase는 반드시 성공해야 하므로 try/catch 없이 한 번만 초기화합니다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 로그인 유지 설정은 웹에서만 필요합니다.
  // (모바일은 기본값이 이미 "로그인 유지"이고, 이 함수를 호출하면 오류가 납니다.)
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // 아래 서비스들은 실패해도 앱 자체는 켜져야 하므로 각각 보호합니다.
  // (보호하지 않으면 하나만 실패해도 앱이 흰 화면에서 멈춥니다.)
  await _safeInit('AuthService', () => AuthService().initialize());
  await _safeInit('AdService', () => AdService().initialize());
  await _safeInit('SubscriptionService', () => SubscriptionService().initialize());

  runApp(const MyApp());
}

Future<void> _safeInit(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (e) {
    debugPrint('❌ $name 초기화 실패: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: 'EasyEnglish',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: child,
        );
      },
      // 로그인 상태에 따라 화면이 자동으로 바뀝니다.
      // 로그인됨 -> 홈(레벨 선택) / 로그인 안 됨 -> 시작하기 화면
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const LevelSelectPage();
          }
          return const SignupPage();
        },
      ),
    );
  }
}
