import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Which tab is currently active. Used to highlight the right icon
/// and to know which route to navigate to on tap.
enum NavTab { home, contacts, alerts, profile }

/// Reusable bottom navigation bar shown on Home, Contacts, Alerts,
/// and Profile screens. Pass the currently active tab; tapping any
/// icon navigates to that tab's route via GetX.
class BottomNavBar extends StatelessWidget {
  final NavTab currentTab;

  // Shows a small red dot on the Alerts icon when there's an active,
  // unread SOS alert — regardless of which tab is currently active.
  final bool showAlertBadge;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    this.showAlertBadge = false,
  });

  void _onTap(NavTab tab) {
    if (tab == currentTab) return; // already on this tab
    switch (tab) {
      case NavTab.home:
        Get.offNamed('/home');
        break;
      case NavTab.contacts:
        Get.offNamed('/contacts');
        break;
      case NavTab.alerts:
        Get.offNamed('/alerts');
        break;
      case NavTab.profile:
        Get.offNamed('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                isActive: currentTab == NavTab.home,
                onTap: () => _onTap(NavTab.home),
              ),
              _NavIcon(
                icon: Icons.people_alt_rounded,
                isActive: currentTab == NavTab.contacts,
                onTap: () => _onTap(NavTab.contacts),
              ),
              _NavIcon(
                icon: Icons.notifications_rounded,
                isActive: currentTab == NavTab.alerts,
                onTap: () => _onTap(NavTab.alerts),
                showBadge: showAlertBadge,
              ),
              _NavIcon(
                icon: Icons.person_rounded,
                isActive: currentTab == NavTab.profile,
                onTap: () => _onTap(NavTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool showBadge;

  const _NavIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primaryPurple : AppColors.subtitle,
            ),
            if (showBadge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.alertDanger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.fieldFill, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
