import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Which tab is currently active. Used to highlight the right icon
/// and to know which route to navigate to on tap.
enum NavTab { home, contacts, alerts, profile }

/// Reusable bottom navigation bar shown on Home, Contacts, Alerts,
/// and Profile screens.
///
/// The Alerts icon shows a red badge with the NUMBER of active SOS alerts
/// this user was notified about. The bar watches Firestore itself, so the
/// badge appears on every screen with no extra wiring.
class BottomNavBar extends StatelessWidget {
  final NavTab currentTab;

  /// No longer needed -- the bar works the count out itself. Kept only so
  /// existing screens that still pass it keep compiling.
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

  /// Live count of active alerts addressed to this user. Filters with
  /// array-contains only and counts 'active' on the phone, so no
  /// Firestore index is needed.
  Stream<int> _activeAlertCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('notifiedUserIds', arrayContains: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where(
                (d) => (d.data()['status'] as String? ?? 'active') == 'active',
              )
              .length,
        );
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
              StreamBuilder<int>(
                stream: _activeAlertCount(),
                builder: (context, snap) {
                  return _NavIcon(
                    icon: Icons.notifications_rounded,
                    isActive: currentTab == NavTab.alerts,
                    onTap: () => _onTap(NavTab.alerts),
                    badgeCount: snap.data ?? 0,
                  );
                },
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
  final int badgeCount;

  const _NavIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
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
            if (badgeCount > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.alertDanger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.fieldFill, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
