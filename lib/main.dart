import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easyenglish/pages/signup_page.dart';
import 'package:easyenglish/pages/level_select_page.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/services/auth_service.dart';
import 'package:easyenglish/services/ad_service.dart';
import 'package:easyenglish/services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService().initialize(); // 추가

  await AdService().initialize();
  await SubscriptionService().initialize();
  
  runApp(const MyApp());
  try {
    // ✅ 수정된 부분: 옵션값 추가
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAuth.instance.setPersistence(
      Persistence.LOCAL,
    );

    debugPrint('✅ Firebase 초기화 완료');
  } catch (e) {
    debugPrint('❌ Firebase 초기화 실패: $e');
  }

  runApp(const MyApp());
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
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: child,
        );
      },
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          debugPrint(
              'Auth 상태: ${snapshot.connectionState}, User: ${snapshot.data?.email}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData) {
            debugPrint('✅ 로그인 성공: ${snapshot.data!.uid}');
            return LevelSelectPage(
              userId: snapshot.data!.uid,
            );
          }

          debugPrint('❌ 로그인 정보 없음');
          return const SignupPage();
        },
      ),
    );
  }
}
