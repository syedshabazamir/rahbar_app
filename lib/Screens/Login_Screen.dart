import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rahbar_app/Controller/Login_controller.dart';
import 'package:rahbar_app/utils/App_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
    ValueChanged<String>? onChanged,
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
            onChanged: onChanged,
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
    final controller = Get.put(LoginController());

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

                // ---- Back button ----
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.title),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 28),

                // ---- Heading ----
                Text(
                  'Welcome back',
                  style: GoogleFonts.tinos(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Someone\'s always within reach',
                  style: TextStyle(fontSize: 15, color: AppColors.subtitle),
                ),

                const SizedBox(height: 28),

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

                // ---- Password ----
                Obx(
                  () => _buildField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: controller.passwordController,
                    obscureText: controller.obscurePassword.value,
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

                const SizedBox(height: 10),

                // ---- Forgot password ----
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Get.toNamed('/forgot-password');
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ---- Log in button ----
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.logIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        disabledBackgroundColor: AppColors.primaryPurple
                            .withOpacity(0.4),
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
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Don't have an account? Create one ----
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.subtitle,
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Create one',
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Get.offNamed('/signup'),
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
