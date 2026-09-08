import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Shows a live map view of where the person who sent the SOS is,
/// plus a shortcut into the live evidence recording.
///
/// NOTE: This uses a stylized custom-painted placeholder instead of a
/// real map. To show an actual map, add a maps package such as
/// `google_maps_flutter` or `flutter_map` and swap out `_MapPlaceholder`
/// for the real map widget, centered on the contact's live coordinates.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final name = (args is Map ? args['name'] : null) ?? 'Amara';
    final firstName = name.toString().split(' ').first;
    final location = (args is Map ? args['location'] : null) ?? 'Jinnah Avenue';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.title),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracking $firstName',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.alertDanger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SOS active',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.alertDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Map placeholder ----
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _MapPlaceholder(),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return _PulsingPin(
                        progress: _pulseController.value,
                        label: firstName,
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---- Bottom info card ----
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$location, near City Hospital',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.title,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => Get.toNamed(
                        '/live-evidence',
                        arguments: {'name': name},
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ringColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.videocam_outlined,
                              size: 18,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Live recording, tap to view',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.title,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.subtitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stylized grid background standing in for a real map tile layer.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6E7DE),
      child: CustomPaint(size: Size.infinite, painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8D2C4)
      ..strokeWidth = 1;

    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The pulsing location marker + label, matching the "Amara" pin
/// with an expanding ring animation.
class _PulsingPin extends StatelessWidget {
  final double progress;
  final String label;

  const _PulsingPin({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + (progress * 1.6);
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryPurpleDark,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.alertDanger,
                    ),
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.alertDanger,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
