import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/Phone_utils.dart';

/// Handles the real signup flow: Firebase Auth account creation +
/// writing the user's profile (including normalized phone) to
/// Firestore. SignupScreen just reads/calls into this — no direct
/// Firebase calls live in the widget itself.
class SignupController extends GetxController {
  // ---- Form controllers (owned here so both the screen and the
  // submit logic share the exact same text state) ----
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  // ---- Reactive UI state ----
  final RxBool isLoading = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool isEmailValid = false.obs;
  final RxBool isPhoneValid = false.obs;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  @override
  void onInit() {
    super.onInit();
    emailController.addListener(_validateEmail);
    phoneController.addListener(_validatePhone);
  }

  void _validateEmail() {
    isEmailValid.value = _emailRegex.hasMatch(emailController.text.trim());
  }

  void _validatePhone() {
    final normalized = normalizePhoneNumber(phoneController.text);
    isPhoneValid.value = isPlausiblePhoneNumber(normalized);
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// Runs the real signup: creates the Firebase Auth account, then
  /// writes the user's profile doc to Firestore with the phone number
  /// normalized to E.164 — the SAME normalizePhoneNumber() used on the
  /// "add trusted contact" screen, so lookups by phone actually match.
  Future<void> signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final normalizedPhone = normalizePhoneNumber(phoneController.text);

    // ---- Basic validation before hitting the network ----
    if (name.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    if (!isEmailValid.value) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (!isPhoneValid.value) {
      _showError('Please enter a valid phone number.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    isLoading.value = true;
    try {
      // 1. Create the Firebase Auth account (email/password).
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;
      final normalizedEmail = email.toLowerCase();

      // 2. Write the user's profile to Firestore. The 'phone' field is
      // what the syncPhoneIndex Cloud Function watches to keep
      // phoneIndex/{phone} up to date for trusted-contact lookups.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': normalizedEmail,
        'phone': normalizedPhone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Write a minimal public existence-check entry, doc-keyed by
      // email. This is what lets the Forgot Password screen verify an
      // email is registered *before* the user is signed in, without
      // exposing the private 'users' collection (name, phone, etc.) to
      // an unauthenticated read. Rules restrict this to: readable by
      // anyone, but only creatable by the account it belongs to, and
      // never editable/deletable from the client.
      await FirebaseFirestore.instance
          .collection('emailIndex')
          .doc(normalizedEmail)
          .set({'uid': uid});

      // 4. Optionally set the display name on the Auth profile too.
      await credential.user!.updateDisplayName(name);

      isLoading.value = false;
      Get.toNamed('/trusted-contact');
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
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      default:
        return e.message ?? 'Signup failed. Please try again.';
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Signup failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF9B2C3A),
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
