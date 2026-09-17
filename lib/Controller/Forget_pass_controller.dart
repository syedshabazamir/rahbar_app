import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Handles the real "forgot password" flow: sends a Firebase Auth
/// password-reset email. ForgotPasswordScreen just reads/calls into
/// this — no direct Firebase calls live in the widget itself, same
/// pattern as SignupController / LoginController.
class ForgotPasswordController extends GetxController {
  final emailController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isEmailValid = false.obs;

  // True once the reset email has actually been sent — the screen
  // swaps to a "check your inbox" confirmation state when this flips.
  final RxBool emailSent = false.obs;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  @override
  void onInit() {
    super.onInit();
    emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    isEmailValid.value = _emailRegex.hasMatch(emailController.text.trim());
  }

  /// Sends the real password-reset email via Firebase Auth — but only
  /// after confirming an account with this email actually exists in
  /// Firestore. This check is needed because Firebase projects with
  /// email-enumeration protection enabled (the current default) let
  /// `sendPasswordResetEmail` succeed silently even for an email that
  /// was never signed up, so `user-not-found` can't be relied on to
  /// catch a typo like "syedshahbazamir@" vs "syedshabazamir@".
  ///
  /// On success, flips `emailSent` so the screen can show a
  /// confirmation state instead of navigating away — there's nothing
  /// to navigate to yet, since the user still needs to check their
  /// inbox and tap the link.
  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();

    if (!isEmailValid.value) {
      _showError('Please enter a valid email address.');
      return;
    }

    isLoading.value = true;
    try {
      final exists = await _accountExists(email);
      if (!exists) {
        isLoading.value = false;
        _showError(
          'No account found with that email. Please check and try again.',
        );
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      isLoading.value = false;
      emailSent.value = true;
    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      _showError(_messageForAuthError(e));
    } on FirebaseException catch (e) {
      // Almost always a Firestore rules problem (e.g. code
      // 'permission-denied') if it lands here — the query itself
      // couldn't run, as opposed to running and finding nothing.
      isLoading.value = false;
      debugPrint(
        'ForgotPassword: Firestore lookup failed — ${e.code}: ${e.message}',
      );
      _showError('Something went wrong. Please try again.');
    } catch (e) {
      isLoading.value = false;
      debugPrint('ForgotPassword: unexpected error — $e');
      _showError('Something went wrong. Please try again.');
    }
  }

  // Looks up the public 'emailIndex' collection (doc id = lowercased
  // email) instead of querying 'users' directly — Firestore rules
  // deny unauthenticated reads/queries on 'users', which holds
  // private data (name, phone). emailIndex holds nothing but a uid
  // pointer and is readable by anyone precisely so this check can run
  // before the person is signed in.
  Future<bool> _accountExists(String email) async {
    // Strip anything beyond a plain trim/lowercase — mobile keyboards
    // sometimes insert invisible characters (non-breaking spaces, etc.)
    // around autocompleted text.
    final cleaned = email.trim().toLowerCase();

    final doc = await FirebaseFirestore.instance
        .collection('emailIndex')
        .doc(cleaned)
        .get();

    // TEMP DEBUG — remove once this is confirmed working.
    debugPrint('ForgotPassword: looked up "$cleaned", exists=${doc.exists}');

    return doc.exists;
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with that email. Please check and try again.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Could not send reset email. Please try again.';
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Reset failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF9B2C3A),
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
