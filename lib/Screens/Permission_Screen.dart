import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rahbar_app/utils/App_colors.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  // Real OS permission status for each toggle, checked on load and
  // whenever the user flips a switch or returns from Settings.
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permission status when the app resumes — covers the case
  // where the user granted/denied a permission from the Settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final location = await Permission.location.status;
    final microphone = await Permission.microphone.status;
    final camera = await Permission.camera.status;
    if (!mounted) return;
    setState(() {
      _locationStatus = location;
      _microphoneStatus = microphone;
      _cameraStatus = camera;
      _loading = false;
    });
  }

  // Called when the user flips a toggle. If turning ON, this fires the
  // real OS permission dialog right then (on-demand, not pre-requested).
  // If turning OFF, apps cannot revoke OS permissions programmatically —
  // we send the user to system Settings to do that themselves.
  Future<void> _handleToggle({
    required Permission permission,
    required bool turningOn,
    required ValueChanged<PermissionStatus> onStatus,
  }) async {
    if (turningOn) {
      final status = await permission.request();
      if (!mounted) return;
      onStatus(status);

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog();
      } else if (status.isDenied) {
        Get.snackbar(
          'Permission needed',
          'Rahbar needs this permission for SOS to work properly.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.title,
          colorText: Colors.white,
        );
      }
    } else {
      // Can't programmatically revoke — route the user to Settings.
      _showOpenSettingsDialog(
        message:
            'To turn this off, disable it for Rahbar in your device Settings.',
      );
    }
  }

  void _showOpenSettingsDialog({String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permission required',
          style: TextStyle(color: AppColors.title),
        ),
        content: Text(
          message ??
              "This permission was denied. You'll need to enable it from your "
                  'device Settings for SOS to work properly.',
          style: const TextStyle(color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Not now',
              style: TextStyle(color: AppColors.subtitle),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canFinishSetup =>
      _locationStatus.isGranted &&
      _microphoneStatus.isGranted &&
      _cameraStatus.isGranted;

  void _onFinishSetupPressed() {
    // All three permissions are already genuinely granted at this point.
    // TODO: navigate into the app, e.g. Get.offAllNamed('/home').
  }

  // Builds one permission row: icon, title + subtitle, and a toggle switch
  // bound to the real, live OS permission status.
  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required Permission permission,
    required ValueChanged<PermissionStatus> onStatus,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ringColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.subtitle,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: status.isGranted,
            onChanged: (turningOn) => _handleToggle(
              permission: permission,
              turningOn: turningOn,
              onStatus: onStatus,
            ),
            activeColor: Colors.white,
            activeTrackColor: AppColors.success,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE3DCE1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ---- Back + step indicator ----
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.title,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Step 3 of 3',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.subtitle,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ---- Heading ----
                    Text(
                      'Allow permissions',
                      style: GoogleFonts.tinos(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Needed so SOS can actually work when it matters',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.subtitle,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ---- Permission tiles (real OS status + on-demand requests) ----
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPermissionTile(
                              icon: Icons.location_on_outlined,
                              title: 'Location',
                              subtitle: 'To share where you are during SOS',
                              status: _locationStatus,
                              permission: Permission.location,
                              onStatus: (s) =>
                                  setState(() => _locationStatus = s),
                            ),
                            _buildPermissionTile(
                              icon: Icons.mic_none_outlined,
                              title: 'Microphone',
                              subtitle: 'To record audio as evidence',
                              status: _microphoneStatus,
                              permission: Permission.microphone,
                              onStatus: (s) =>
                                  setState(() => _microphoneStatus = s),
                            ),
                            _buildPermissionTile(
                              icon: Icons.videocam_outlined,
                              title: 'Camera',
                              subtitle: 'To record video as evidence',
                              status: _cameraStatus,
                              permission: Permission.camera,
                              onStatus: (s) =>
                                  setState(() => _cameraStatus = s),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---- Finish setup button ----
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _canFinishSetup
                            ? _onFinishSetupPressed
                            : null,
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
                        child: const Text(
                          'Finish setup',
                          style: TextStyle(
                            fontSize: 17,
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
    );
  }
}
