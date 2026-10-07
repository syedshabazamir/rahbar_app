import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:rahbar_app/utils/App_colors.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  // Separate from _locationStatus: this is whether the phone's GPS/
  // location SERVICE is switched on at all, not just whether the app
  // has permission to use it. Both need to be true for SOS to
  // actually be able to share a location.
  bool _locationServiceEnabled = true;

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
    final notification = await Permission.notification.status;
    final serviceEnabled = await loc.Location().serviceEnabled();
    if (!mounted) return;
    setState(() {
      _locationStatus = location;
      _microphoneStatus = microphone;
      _cameraStatus = camera;
      _notificationStatus = notification;
      _locationServiceEnabled = serviceEnabled;
      _loading = false;
    });
  }

  // Location gets its own handler (instead of the generic
  // _handleToggle below) because turning it on needs one more step
  // than the others: after permission is granted, it also has to
  // check whether location SERVICES are switched on, and if not, try
  // to show Android's native in-app "Turn on Location" popup right
  // here during onboarding -- rather than the person only discovering
  // it's off later, mid-emergency, when sending an SOS.
  Future<void> _handleLocationToggle(bool turningOn) async {
    if (!turningOn) {
      _showOpenSettingsDialog(
        message:
            'To turn this off, disable it for Rahbar in your device Settings.',
      );
      return;
    }

    final status = await Permission.location.request();
    if (!mounted) return;
    setState(() => _locationStatus = status);

    if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog();
      return;
    }
    if (!status.isGranted) {
      Get.snackbar(
        'Permission needed',
        'Rahbar needs location access for SOS to work properly.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.title,
        colorText: Colors.white,
      );
      return;
    }

    // Permission granted -- now make sure the service itself is on.
    // On Android this can show a native popup right in the app; on
    // iOS, Apple does not allow that dialog, so this just checks the
    // current state and the person has to enable it via Settings.
    final locationService = loc.Location();
    bool serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
    }
    if (!mounted) return;
    setState(() => _locationServiceEnabled = serviceEnabled);

    if (!serviceEnabled) {
      Get.snackbar(
        'Location is off',
        'Please turn on Location Services on your phone for SOS to work.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.title,
        colorText: Colors.white,
      );
    }
  }

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
      _locationServiceEnabled &&
      _microphoneStatus.isGranted &&
      _cameraStatus.isGranted &&
      _notificationStatus.isGranted;

  void _onFinishSetupPressed() {
    // All permissions AND location services are genuinely on at this
    // point. Clears the whole onboarding stack so back-navigation
    // from Home doesn't return the user to signup/permissions/etc.
    Get.offAllNamed('/home');
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required Permission permission,
    required ValueChanged<PermissionStatus> onStatus,
    ValueChanged<bool>? customOnChanged,
    String? warningText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
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
                onChanged:
                    customOnChanged ??
                    (turningOn) => _handleToggle(
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
          if (warningText != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _handleLocationToggle(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ringColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningText,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.title,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                              customOnChanged: _handleLocationToggle,
                              warningText:
                                  (_locationStatus.isGranted &&
                                      !_locationServiceEnabled)
                                  ? 'Location permission is on, but Location '
                                        'Services are off. Tap to turn on.'
                                  : null,
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
                            _buildPermissionTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Notifications',
                              subtitle:
                                  "To alert you when a trusted contact sends SOS",
                              status: _notificationStatus,
                              permission: Permission.notification,
                              onStatus: (s) =>
                                  setState(() => _notificationStatus = s),
                            ),
                          ],
                        ),
                      ),
                    ),
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
