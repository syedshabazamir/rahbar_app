import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/Screens/Active_Alert_Screen.dart';
import 'package:rahbar_app/Screens/Add_trust_Cont_Screen.dart';
import 'package:rahbar_app/Screens/Aert_Screen.dart';
import 'package:rahbar_app/Screens/Contact_Screen.dart';
import 'package:rahbar_app/Screens/Forget_pass_screen.dart';
import 'package:rahbar_app/Screens/Home_Screen.dart';
import 'package:rahbar_app/Screens/Live_evidance_screen.dart';
import 'package:rahbar_app/Screens/Permission_Screen.dart';
import 'package:rahbar_app/Screens/Profile_Screen.dart';
import 'package:rahbar_app/Screens/Incoming_Alert_Screen.dart';
import 'package:rahbar_app/Screens/Live_Tracking_Screen.dart';
import 'package:rahbar_app/Screens/Recorded_evidance_screen.dart';
import 'package:rahbar_app/Screens/wrapperscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rahbar_app/utils/Sos_vibration.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

/// Handles a push notification that arrives while the app is fully
/// backgrounded or killed. MUST be a top-level (or static) function,
/// not a method on a class or a closure -- Flutter runs this in a
/// separate isolate, so it can't close over any app state.
///
/// This expects the data payload to include a 'type' of 'sos_alert'
/// and an 'alertId' (the Supabase Edge Function sends both).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized again here -- this runs in its own
  // isolate, separate from main()'s.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDVPOHPPJdOVQoQm7YFPKgVhyin0gjuZ8Y",
        appId: "1:126284878350:android:a8ccc7a4800285caa9225f",
        messagingSenderId: "126284878350",
        projectId: "rahbar-f7d5c",
        storageBucket: "rahbar-f7d5c.firebasestorage.app",
      ),
    );
  }
  // Nothing else to do here -- Android/iOS display the notification
  // automatically from the 'notification' payload while backgrounded,
  // and the phone vibrates via the `sos_alerts` channel created in
  // MainActivity.kt. This handler exists so 'data'-only messages aren't
  // silently dropped.
}

void main() async {
  // MUST be the very first call -- dotenv.load() and Supabase.initialize()
  // below both use platform channels that require the binding to already
  // be ready.
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env["SUPABASE_URL"]!,
    anonKey: dotenv.env["SUPABASE_ANON_KEY"]!,
  );

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDVPOHPPJdOVQoQm7YFPKgVhyin0gjuZ8Y",
        appId: "1:126284878350:android:a8ccc7a4800285caa9225f",
        messagingSenderId: "126284878350",
        projectId: "rahbar-f7d5c",
        storageBucket: "rahbar-f7d5c.firebasestorage.app",
      ),
    );
  }

  // Register the background handler BEFORE runApp -- must happen here
  // in main(), not inside a widget.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

/// Given a RemoteMessage (whether tapped from the tray, or the app's
/// very first launch was caused by tapping one), routes to the right
/// screen. Centralized here so cold-start and warm-tap handling stay
/// in sync instead of duplicating logic.
void _handleNotificationTap(RemoteMessage message) {
  final type = message.data['type'];
  final alertId = message.data['alertId'];

  if (type == 'sos_alert' && alertId != null) {
    Get.toNamed('/incoming-alert', arguments: {'alertId': alertId});
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // App was fully closed and opened BY tapping a notification.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message);
    });

    // App was backgrounded (not closed) and brought forward by
    // tapping a notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App was already open and in the foreground when the push
    // arrived. FCM does NOT auto-display a system notification for this
    // case, so we buzz the phone ourselves and go straight to the
    // incoming-alert screen.
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'sos_alert') vibrateForSos();
      _handleNotificationTap(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Rahbar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const WrapperScreen()),
        GetPage(name: '/splash', page: () => const SplashScreen()),
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
        GetPage(
          name: '/forgot-password',
          page: () => const ForgotPasswordScreen(),
        ),
        GetPage(name: '/active-alert', page: () => const ActiveAlertScreen()),
      ],
    );
  }
}
