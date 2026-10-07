import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen SOS takeover shown to a trusted contact when someone
/// they're watching over sends an alert. Reached by tapping the push
/// notification (see main.dart's _handleNotificationTap), which
/// passes { 'alertId': ... }.
///
/// Streams the alert doc live (location/status keep changing while
/// active), and does a one-time fetch of the sender's profile (name,
/// phone) since that doesn't change mid-alert.
class IncomingAlertScreen extends StatelessWidget {
  const IncomingAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final alertId = (args is Map ? args['alertId'] : null)?.toString();

    if (alertId == null || alertId.isEmpty) {
      return const _ErrorScaffold(message: 'This alert link is invalid.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .doc(alertId)
          .snapshots(),
      builder: (context, alertSnap) {
        if (alertSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (!alertSnap.hasData || !alertSnap.data!.exists) {
          return const _ErrorScaffold(
            message: 'This alert could not be found.',
          );
        }

        final alert = alertSnap.data!.data()!;
        final senderId = alert['senderId'] as String?;
        final status = alert['status'] as String? ?? 'active';
        final location = alert['location'] as Map<String, dynamic>?;

        if (senderId == null) {
          return const _ErrorScaffold(
            message: 'This alert is missing sender info.',
          );
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            final userData = userSnap.data?.data();
            final name =
                (userData?['name'] as String?)?.trim().isNotEmpty == true
                ? userData!['name'] as String
                : 'Someone';
            final phone = userData?['phone'] as String?;
            final firstName = name.split(RegExp(r'\s+')).first;
            final initials = _initialsFrom(name);

            return _IncomingAlertBody(
              alertId: alertId,
              senderName: name,
              firstName: firstName,
              initials: initials,
              phone: phone,
              isActive: status == 'active',
              hasLocation: location != null,
            );
          },
        );
      },
    );
  }

  static String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _IncomingAlertBody extends StatelessWidget {
  final String alertId;
  final String senderName;
  final String firstName;
  final String initials;
  final String? phone;
  final bool isActive;
  final bool hasLocation;

  const _IncomingAlertBody({
    required this.alertId,
    required this.senderName,
    required this.firstName,
    required this.initials,
    required this.phone,
    required this.isActive,
    required this.hasLocation,
  });

  void _onViewLiveLocation() {
    Get.toNamed(
      '/live-tracking',
      arguments: {'alertId': alertId, 'name': senderName},
    );
  }

  Future<void> _onCallNow() async {
    if (phone == null || phone!.isEmpty) {
      Get.snackbar(
        'No phone number',
        "$firstName hasn't added a phone number to their account.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.title,
        colorText: Colors.white,
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.alertMaroon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        isActive ? 'SOS ALERT' : 'ALERT ENDED',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const Spacer(flex: 3),

              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                isActive ? '$firstName needs help' : '$firstName is safe now',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? (hasLocation
                          ? 'Sharing their live location with you'
                          : 'Getting their location...')
                    : 'This alert has ended.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 4),

              if (isActive) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: hasLocation ? _onViewLiveLocation : null,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _onCallNow,
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
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
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

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.alertMaroon,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.alertMaroon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
