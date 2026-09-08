import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rahbar_app/Controller/Signup_controller.dart';
import 'package:rahbar_app/utils/App_colors.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  // Builds a labeled input field matching the design:
  // grey label, white rounded field, optional trailing icon/helper text.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? trailing,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.fieldLabel,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16, color: AppColors.title),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.fieldHint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: trailing,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(fontSize: 12.5, color: AppColors.helperText),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Registers (or reuses) the controller that owns all form state
    // and the real Firebase Auth + Firestore signup logic.
    final controller = Get.put(SignupController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ---- Back + step indicator ----
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.title,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Step 1 of 3',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.subtitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ---- Heading ----
                Text(
                  'Create your account',
                  style: GoogleFonts.tinos(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'It only takes a minute',
                  style: TextStyle(fontSize: 15, color: AppColors.subtitle),
                ),

                const SizedBox(height: 28),

                // ---- Full name ----
                _buildField(
                  label: 'Full name',
                  hint: 'e.g. Amara Khan',
                  controller: controller.nameController,
                ),

                const SizedBox(height: 20),

                // ---- Email address ----
                Obx(
                  () => _buildField(
                    label: 'Email address',
                    hint: 'e.g. amara@gmail.com',
                    controller: controller.emailController,
                    keyboardType: TextInputType.emailAddress,
                    trailing: controller.isEmailValid.value
                        ? const Icon(
                            Icons.check,
                            color: AppColors.success,
                            size: 20,
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Phone number ----
                // Stored so trusted contacts can find this account by
                // phone number and route SOS notifications correctly.
                // NOT used for login — login stays email/password.
                Obx(
                  () => _buildField(
                    label: 'Phone number',
                    hint: 'e.g. 0300 1234567',
                    controller: controller.phoneController,
                    keyboardType: TextInputType.phone,
                    helperText: "So trusted contacts can find and alert you",
                    trailing: controller.isPhoneValid.value
                        ? const Icon(
                            Icons.check,
                            color: AppColors.success,
                            size: 20,
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Password ----
                Obx(
                  () => _buildField(
                    label: 'Password',
                    hint: 'Create a password',
                    controller: controller.passwordController,
                    obscureText: controller.obscurePassword.value,
                    helperText: 'At least 8 characters',
                    trailing: IconButton(
                      onPressed: controller.togglePasswordVisibility,
                      icon: Icon(
                        controller.obscurePassword.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.fieldHint,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ---- Continue button (shows a spinner while signing up) ----
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        disabledBackgroundColor: AppColors.primaryPurple
                            .withOpacity(0.6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Already have an account? Log in ----
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.subtitle,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Get.offNamed('/login'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
