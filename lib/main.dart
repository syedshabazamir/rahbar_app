import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/Screens/Add_trust_Cont_Screen.dart';
import 'package:rahbar_app/Screens/Aert_Screen.dart';
import 'package:rahbar_app/Screens/Contact_Screen.dart';
import 'package:rahbar_app/Screens/Home_Screen.dart';
import 'package:rahbar_app/Screens/Live_evidance_screen.dart';
import 'package:rahbar_app/Screens/Permission_Screen.dart';
import 'package:rahbar_app/Screens/Profile_Screen.dart';
import 'package:rahbar_app/Screens/Incoming_Alert_Screen.dart';
import 'package:rahbar_app/Screens/Live_Tracking_Screen.dart';
import 'package:rahbar_app/Screens/Recorded_evidance_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyClYCFenxWW3kj3QZWDkZazB9XkxfVU3vI",
      authDomain: "rahbar-f7d5c.firebaseapp.com",
      projectId: "rahbar-f7d5c",
      storageBucket: "rahbar-f7d5c.firebasestorage.app",
      messagingSenderId: "126284878350",
      appId: "1:126284878350:web:806c2e0e57abf9ada9225f",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Rahbar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
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
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/contacts', page: () => const ContactsScreen()),
        GetPage(name: '/alerts', page: () => const AlertsScreen()),
        GetPage(name: '/profile', page: () => const ProfileScreen()),
        GetPage(
          name: '/incoming-alert',
          page: () => const IncomingAlertScreen(),
        ),
        GetPage(name: '/live-tracking', page: () => const LiveTrackingScreen()),
        GetPage(name: '/live-evidence', page: () => const LiveEvidenceScreen()),
        GetPage(
          name: '/recorded-evidence',
          page: () => const RecordedEvidenceScreen(),
        ),
      ],
    );
  }
}
