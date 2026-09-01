import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rahbar_app/utils/App_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  // Navigation handlers, using GetX's Get.toNamed for routing.
  // Replace '/login' and '/signup' with your actual named routes,
  // or swap for Get.to(() => LoginScreen()) if you're not using them.
  void _onLogInPressed() => Get.toNamed('/login');

  void _onCreateAccountPressed() => Get.toNamed('/signup');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Push the logo block down from the top, similar to design.
              const Spacer(flex: 3),

              // ---- Logo circle with ring ----
              _LogoBadge(),

              const SizedBox(height: 28),

              // ---- App name ----
              Text(
                'Rahbar',
                style: GoogleFonts.tinos(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),

              const SizedBox(height: 10),

              // ---- Tagline (wraps to two lines like the design) ----
              const Text(
                "Someone's always within reach when you need them",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.subtitle,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),

              // Push buttons toward the bottom, similar to design.
              const Spacer(flex: 5),

              // ---- Create an account button (filled) ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onCreateAccountPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create an account',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ---- Log in button (outlined) ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _onLogInPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.title,
                    side: const BorderSide(
                      color: AppColors.outlineButtonBorder,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular purple badge with the ring and shield+heart icon.
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.ringColor,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryPurple,
        ),
        alignment: Alignment.center,
        // Custom painted shield + heart, matching the outline icon in the design.
        child: CustomPaint(
          size: const Size(48, 48),
          painter: _ShieldHeartPainter(),
        ),
      ),
    );
  }
}

/// Draws a simple shield outline with a heart cut-out, similar to the logo.
class _ShieldHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Shield outline path.
    final shieldPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.92, h * 0.16)
      ..lineTo(w * 0.92, h * 0.5)
      ..cubicTo(w * 0.92, h * 0.78, w * 0.72, h * 0.94, w * 0.5, h)
      ..cubicTo(w * 0.28, h * 0.94, w * 0.08, h * 0.78, w * 0.08, h * 0.5)
      ..lineTo(w * 0.08, h * 0.16)
      ..close();

    canvas.drawPath(shieldPath, paint);

    // Small filled heart in the center-bottom of the shield.
    final heartPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final heartPath = Path();
    final cx = w * 0.5;
    final cy = h * 0.52;
    final r = w * 0.14;

    heartPath.moveTo(cx, cy + r * 0.9);
    heartPath.cubicTo(
      cx - r * 1.6,
      cy - r * 0.4,
      cx - r * 0.5,
      cy - r * 1.5,
      cx,
      cy - r * 0.4,
    );
    heartPath.cubicTo(
      cx + r * 0.5,
      cy - r * 1.5,
      cx + r * 1.6,
      cy - r * 0.4,
      cx,
      cy + r * 0.9,
    );
    heartPath.close();

    canvas.drawPath(heartPath, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
