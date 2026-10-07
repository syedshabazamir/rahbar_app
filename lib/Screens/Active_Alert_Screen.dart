import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/Controller/Alert_Controller.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Shown to the SENDER right after they trigger SOS. Reads everything
/// live from AlertController (Get.find) -- real GPS position, real
/// elapsed time -- rather than a one-time snapshot passed as
/// navigation arguments, since both keep changing while this screen
/// is open.
class ActiveAlertScreen extends StatefulWidget {
  const ActiveAlertScreen({super.key});

  @override
  State<ActiveAlertScreen> createState() => _ActiveAlertScreenState();
}

class _ActiveAlertScreenState extends State<ActiveAlertScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AlertController _alert;

  // True while stopAlert() is running. Shown on the button, since
  // stopAlert() can take a few seconds -- it waits for the video loop
  // to save/upload its last clip before returning -- and without this,
  // the button just sits there looking unresponsive/frozen.
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _alert = Get.find<AlertController>();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onStopAlert() async {
    if (_isStopping) return; // ignore a second tap while already stopping
    setState(() => _isStopping = true);

    try {
      await _alert.stopAlert();
    } catch (_) {
      // Even if something fails, still leave the screen below.
    }

    if (!mounted) return;
    Get.delete<AlertController>(); // free it now that the alert is over
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.eveningDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Obx(() {
            final position = _alert.currentPosition.value;
            final locationLabel = position == null
                ? 'Getting location...'
                : '${position.latitude.toStringAsFixed(5)}, '
                      '${position.longitude.toStringAsFixed(5)}';

            return Column(
              children: [
                const SizedBox(height: 16),

                // ---- "ALERT SENT" + recording status ----
                const Text(
                  'ALERT SENT',
                  style: TextStyle(
                    color: AppColors.alertDanger,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.alertDanger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sharing live location',
                      style: TextStyle(
                        color: AppColors.alertDanger,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 3),

                // ---- Pulsing SOS icon ----
                SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [..._buildPulsingRings(), child!],
                      );
                    },
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.alertDanger,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.alertDanger.withOpacity(0.4),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ---- Notified line ----
                const Text(
                  'Contacts notified',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  position == null
                      ? 'Waiting for GPS fix...'
                      : 'Live location shared just now',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),

                const SizedBox(height: 22),

                // ---- Live location pill (real lat/lng) ----
                _InfoPill(
                  icon: Icons.location_on_outlined,
                  label: locationLabel,
                ),
                const SizedBox(height: 10),

                // ---- Elapsed time pill (real timer) ----
                _InfoPill(
                  icon: Icons.videocam_outlined,
                  label: 'Active · ${_alert.formattedElapsed}',
                ),

                const SizedBox(height: 22),

                // ---- Stop alert button ----
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isStopping ? null : _onStopAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ringColor,
                      disabledBackgroundColor: AppColors.ringColor.withOpacity(
                        0.6,
                      ),
                      foregroundColor: const Color(0xFF9B2C3A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isStopping
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF9B2C3A),
                              ),
                            ),
                          )
                        : const Text(
                            "I'm safe now, stop alert",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            );
          }),
        ),
      ),
    );
  }

  List<Widget> _buildPulsingRings() {
    return [0.0, 0.5].map((offset) {
      final t = (_pulseController.value + offset) % 1.0;
      final scale = 0.6 + (t * 0.4);
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.3;
      return Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.alertDanger, width: 1.5),
            ),
          ),
        ),
      );
    }).toList();
  }
}

/// A dark rounded pill row used for the location/status lines.
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.eveningCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.alertDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
