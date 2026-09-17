import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// App entry gate: decides where the user lands before they see
/// anything else.
///
/// - Already signed in (a real Firebase Auth session) -> straight to
///   Home, skipping Splash/Login/Signup entirely.
/// - Not signed in -> Splash screen, which carries on to
///   Login/Signup as normal.
///
/// This should be the app's entry route ('/'), with Splash moved to
/// its own named route ('/splash') so this screen has somewhere to
/// redirect to:
///
///   getPages: [
///     GetPage(name: '/', page: () => const WrapperScreen()),
///     GetPage(name: '/splash', page: () => const SplashScreen()),
///     ... your other routes ...
///   ]
class WrapperScreen extends StatefulWidget {
  const WrapperScreen({super.key});

  @override
  State<WrapperScreen> createState() => _WrapperScreenState();
}

class _WrapperScreenState extends State<WrapperScreen> {
  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  // Waits for Firebase Auth's actual restored session state rather
  // than trusting `FirebaseAuth.instance.currentUser` on the very
  // first frame -- that can still be null for a moment while Firebase
  // is restoring a persisted session from disk, which would wrongly
  // send an already-logged-in user back to Splash/Login.
  Future<void> _decideRoute() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;

    if (!mounted) return;

    if (user != null) {
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brief neutral loading state while _decideRoute() resolves --
    // this should be on screen for a few hundred milliseconds at most.
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
    );
  }
}
