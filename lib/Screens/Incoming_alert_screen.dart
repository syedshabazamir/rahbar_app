import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Full-screen SOS takeover shown to a trusted contact when someone
/// they're watching over sends an alert. Reached from tapping an
/// alert in AlertsScreen; expects arguments: name, initials, location.
class IncomingAlertScreen extends StatelessWidget {
  const IncomingAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final name = (args is Map ? args['name'] : null) ?? 'Amara Khan';
    final initials = (args is Map ? args['initials'] : null) ?? 'AK';
    final location = (args is Map ? args['location'] : null) ?? 'Jinnah Avenue';
    final firstName = name.toString().split(' ').first;

    void onViewLiveLocation() {
      Get.toNamed(
        '/live-tracking',
        arguments: {'name': name, 'location': location},
      );
    }

    void onCallNow() {
      // TODO: launch a real phone call, e.g. with url_launcher:
      // launchUrl(Uri(scheme: 'tel', path: phoneNumber));
      Get.snackbar(
        'Calling $firstName…',
        'This would start a real phone call.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.title,
        colorText: Colors.white,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.alertMaroon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ---- Back + label ----
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'SOS ALERT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // balances the back button
                ],
              ),

              const Spacer(flex: 3),

              // ---- Avatar ----
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---- Message ----
              Text(
                '$firstName needs help',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent just now from $location, near City Hospital',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 4),

              // ---- View live location ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: onViewLiveLocation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  label: const Text(
                    'View live location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ---- Call now ----
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onCallNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alertMaroonLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.call_outlined, size: 20),
                  label: Text(
                    'Call $firstName now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
