import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/Screens/Add_trust_Cont_Screen.dart';
import 'package:rahbar_app/Screens/Permission_Screen.dart';
import 'package:rahbar_app/Screens/SignUp_Screen.dart';
import 'package:rahbar_app/Screens/Splash_Screen.dart';
import 'package:rahbar_app/Screens/Login_Screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Rahbar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      // Route names must match EXACTLY (case-sensitive) what
      // Get.toNamed() is called with inside SplashScreen,
      // SignupScreen, and LoginScreen.
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/signup', page: () => const SignupScreen()),
        GetPage(
          name: '/trusted-contact',
          page: () => const TrustedContactScreen(),
        ),
        GetPage(name: '/permissions', page: () => const PermissionsScreen()),
      ],
    );
  }
}
