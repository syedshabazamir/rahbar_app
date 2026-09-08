import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

/// A single active SOS alert shown in the list.
class _AlertItem {
  final String name;
  final String initials;
  final String location;
  final String status;

  _AlertItem({
    required this.name,
    required this.initials,
    required this.location,
    required this.status,
  });
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  // TODO: replace with real active alerts from your backend / push
  // notification payload.
  static final List<_AlertItem> _alerts = [
    _AlertItem(
      name: 'Amara Khan',
      initials: 'AK',
      location: 'Jinnah Avenue',
      status: 'SOS active',
    ),
  ];

  void _openAlert(_AlertItem alert) {
    Get.toNamed(
      '/incoming-alert',
      arguments: {
        'name': alert.name,
        'initials': alert.initials,
        'location': alert.location,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveAlerts = _alerts.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              const SizedBox(height: 20),

              // ---- Alert list ----
              Expanded(
                child: hasActiveAlerts
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final alert in _alerts)
                              _AlertCard(
                                alert: alert,
                                onTap: () => _openAlert(alert),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'No active alerts right now.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.subtitle,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.alerts,
        showAlertBadge: hasActiveAlerts,
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AlertItem alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.alertDanger.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.alertDanger,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.status} · ${alert.location}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.alertDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.subtitle),
          ],
        ),
      ),
    );
  }
}
