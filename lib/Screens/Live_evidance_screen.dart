import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Shows the live audio/video evidence being streamed from the
/// victim's phone during an active SOS, with an option to share it
/// directly with emergency services.
class LiveEvidenceScreen extends StatelessWidget {
  const LiveEvidenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final name = (args is Map ? args['name'] : null) ?? 'Amara';
    final firstName = name.toString().split(' ').first;

    void onShareWithEmergencyServices() {
      // TODO: wire this to your real emergency-services handoff flow
      // (e.g. sharing a secure link, or dialing local emergency dispatch).
      Get.snackbar(
        'Sharing evidence…',
        'This would share the live stream with emergency services.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryPurple,
        colorText: Colors.white,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.eveningDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ---- Header ----
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Live evidence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---- Video placeholder ----
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.eveningCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.videocam_outlined,
                          size: 28,
                          color: AppColors.alertDanger,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "Streaming from $firstName's phone",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chunk 4 of recording',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ---- Sync status ----
              const Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.alertDanger),
                  SizedBox(width: 8),
                  Text(
                    'Synced to cloud · 00:42',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ---- Share with emergency services ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onShareWithEmergencyServices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ringColor,
                    foregroundColor: AppColors.title,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Share with emergency services',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
