import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // TODO: replace with real permission state (e.g. from permission_handler)
  bool _locationEnabled = true;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;

  // Real profile data, loaded from users/{uid} in Firestore — the
  // same doc SignupController writes at signup.
  String? _name;
  String? _phone;
  bool _isLoadingProfile = true;

  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _name = (data?['name'] as String?)?.trim();
        _phone = (data?['phone'] as String?)?.trim();
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  // "Amara Khan" -> "AK"; falls back to "?" if there's nothing usable.
  String get _initials {
    final trimmed = _name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  // Confirms first (logging out mid-emergency by accident would be
  // bad), then signs out of Firebase Auth for real and clears the
  // whole navigation stack so back-navigation can't return to a
  // signed-out session.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?', style: TextStyle(color: AppColors.title)),
        content: const Text(
          "You'll need to sign back in to use Rahbar again.",
          style: TextStyle(color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.subtitle),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Log out',
              style: TextStyle(
                color: AppColors.alertMaroon,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // Clears the whole stack so back-navigation from Login can't
      // return to a screen that assumed a signed-in user.
      Get.offAllNamed('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      Get.snackbar(
        'Could not log out',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- User card ----
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryPurple,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _isLoadingProfile
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primaryPurple,
                                            ),
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _name?.isNotEmpty == true
                                              ? _name!
                                              : 'Unnamed user',
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.title,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (_phone?.isNotEmpty == true)
                                          Text(
                                            _phone!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.subtitle,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ---- Permission toggles ----
                      _PermissionTile(
                        icon: Icons.location_on_outlined,
                        label: 'Location access',
                        value: _locationEnabled,
                        onChanged: (v) => setState(() => _locationEnabled = v),
                      ),
                      const SizedBox(height: 12),
                      _PermissionTile(
                        icon: Icons.mic_none_outlined,
                        label: 'Microphone access',
                        value: _microphoneEnabled,
                        onChanged: (v) =>
                            setState(() => _microphoneEnabled = v),
                      ),
                      const SizedBox(height: 12),
                      _PermissionTile(
                        icon: Icons.videocam_outlined,
                        label: 'Camera access',
                        value: _cameraEnabled,
                        onChanged: (v) => setState(() => _cameraEnabled = v),
                      ),

                      const SizedBox(height: 20),

                      // ---- Recorded evidence ----
                      _ProfileLinkTile(
                        icon: Icons.folder_outlined,
                        label: 'Recorded evidence',
                        subtitle: 'View saved photos, audio, and video',
                        onTap: () => Get.toNamed('/recorded-evidence'),
                      ),

                      const SizedBox(height: 40),

                      // ---- Log out ----
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoggingOut ? null : _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.alertMaroon,
                            side: BorderSide(
                              color: AppColors.alertMaroon.withOpacity(0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoggingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.alertMaroon,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Log out',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.profile),
    );
  }
}

class _ProfileLinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileLinkTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withOpacity(0.1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primaryPurple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.subtitle,
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

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.title,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}
