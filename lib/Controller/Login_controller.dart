import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Handles the real login flow: Firebase Auth sign-in with
/// email/password. LoginScreen just reads/calls into this — no direct
/// Firebase calls live in the widget itself, same pattern as
/// SignupController.
class LoginController extends GetxController {
  // ---- Form controllers ----
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // ---- Reactive UI state ----
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool isEmailValid = false.obs;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  @override
  void onInit() {
    super.onInit();
    emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    isEmailValid.value = _emailRegex.hasMatch(emailController.text.trim());
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// Runs the real login: signs in with Firebase Auth and always lands
  /// on /home on success (per current app flow — onboarding progress
  /// isn't re-checked here).
  Future<void> logIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    // ---- Basic validation before hitting the network ----
    if (!isEmailValid.value) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    isLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      isLoading.value = false;
      // Clears the auth stack so back-navigation from Home doesn't
      // return the user to login/signup.
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      _showError(_messageForAuthError(e));
    } catch (e) {
      isLoading.value = false;
      _showError('Something went wrong. Please try again.');
    }
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Login failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF9B2C3A),
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
