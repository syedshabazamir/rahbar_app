import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:rahbar_app/utils/App_colors.dart';

/// Shows a REAL map (OpenStreetMap tiles via flutter_map -- no API
/// key, no billing account) centered on where the person who sent
/// the SOS is, driven by real coordinates streamed from
/// alerts/{alertId}.location.
///
/// NOTE: reverse geocoding (turning coordinates into a street/town
/// name) was removed -- the `geocoding` package's Android build
/// requires compileSdk 34+, which this project isn't on yet. The
/// info card below shows raw lat/lng instead. To bring the street
/// name back later: upgrade Flutter (flutter upgrade), which bumps
/// the default compileSdk, then re-add `geocoding` and the
/// _maybeReverseGeocode logic.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final alertId = (args is Map ? args['alertId'] : null)?.toString();
    final name = (args is Map ? args['name'] : null)?.toString() ?? 'them';
    final firstName = name.split(RegExp(r'\s+')).first;

    if (alertId == null || alertId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This tracking link is invalid.'),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .doc(alertId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final status = data?['status'] as String? ?? 'active';
        final isActive = status == 'active';
        final location = data?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        final hasLocation = lat != null && lng != null;

        if (hasLocation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(
                latlng.LatLng(lat, lng),
                _mapController.camera.zoom == 0
                    ? 16
                    : _mapController.camera.zoom,
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // ---- Header ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tracking $firstName',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.title,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.alertDanger
                                      : AppColors.subtitle,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? 'SOS active' : 'Alert ended',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isActive
                                      ? AppColors.alertDanger
                                      : AppColors.subtitle,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---- Real map ----
                Expanded(
                  child: !hasLocation
                      ? const Center(
                          child: Text(
                            'Waiting for location...',
                            style: TextStyle(
                              color: AppColors.subtitle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: latlng.LatLng(lat, lng),
                            initialZoom: 16,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.rahbar.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: latlng.LatLng(lat, lng),
                                  width: 60,
                                  height: 60,
                                  child: _LivePin(isActive: isActive),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),

                // ---- Bottom info card ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.fieldBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                // No reverse geocoding right now --
                                // shows raw coordinates.
                                hasLocation
                                    ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                    : 'Location not available yet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.title,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () => Get.toNamed(
                            '/live-evidence',
                            arguments: {'alertId': alertId, 'name': name},
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ringColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.videocam_outlined,
                                  size: 18,
                                  color: AppColors.primaryPurple,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'View recorded evidence',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.title,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.subtitle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LivePin extends StatelessWidget {
  final bool isActive;
  const _LivePin({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.alertDanger : AppColors.subtitle;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
