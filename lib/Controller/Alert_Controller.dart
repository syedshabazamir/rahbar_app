import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:rahbar_app/servives/Evidance_recorder_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns the lifecycle of one active SOS alert.
///
/// EVIDENCE: each recorded video clip is now saved TWICE -- once to
/// local device storage (via EvidenceRecorderService, so it shows up
/// in RecordedEvidenceScreen for the victim), and once uploaded to
/// Supabase Storage (so trusted contacts can see it remotely). Both
/// happen from the SAME local file, so what the victim sees locally
/// and what contacts see remotely are guaranteed to be the same clip.
/// Each clip's local copy also carries the EXACT start/stop elapsed
/// seconds read live from this controller's own counter, so
/// RecordedEvidenceScreen can show the same mm:ss range the person
/// saw on screen while it was recording.
///
/// STORAGE: uploads go through the `rahbar` Edge Function's
/// "upload-url" action, which checks the caller owns this alert
/// before handing out a signed upload URL. Only video/mp4 is accepted
/// right now -- the one-shot photo (if you add one) stays local-only
/// until the bucket/mime rules are extended.
///
/// ORDER OF OPERATIONS: the alert doc is created FIRST, before
/// permissions/GPS/camera are touched, since that write is what
/// triggers contacts being notified.
///
/// LOCATION keeps updating with the phone locked (Android foreground
/// service / iOS allowBackgroundLocationUpdates). If location services
/// are OFF when SOS is sent, Android shows its native in-app "Turn on
/// Location" popup via the `location` package -- no leaving the app.
/// iOS does not allow this dialog at all (Apple platform restriction);
/// there, the person has to enable it manually in Settings.
///
/// VIDEO only records while the app is in the foreground -- both OSes
/// suspend camera access the moment the app backgrounds.
class AlertController extends GetxController {
  final RxBool isActive = false.obs;
  final RxString alertId = ''.obs;
  final RxInt elapsedSeconds = 0.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);

  final RxBool isRecordingClip = false.obs;
  final RxInt clipsUploaded = 0.obs;

  final RxBool alertSynced = false.obs;
  final RxInt reachableContacts = 0.obs;
  final RxnString warning = RxnString();

  StreamSubscription<Position>? _positionSub;
  Timer? _elapsedTimer;

  CameraController? _cameraController;
  bool _videoLoopRunning = false;
  Future<void>? _videoLoopFuture;

  static const Duration _clipDuration = Duration(seconds: 20);

  // ---- Edge Function helper --------------------------------------------

  Future<Map<String, dynamic>?> _callRahbar(Map<String, dynamic> body) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) return null;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'rahbar',
        headers: {'x-firebase-token': idToken},
        body: body,
      );
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Closes alerts this user left "active" (app killed, or the End write
  /// never reached the server). Call once when Home opens. Does nothing
  /// while a real SOS is running on this phone.
  static Future<void> endStaleAlerts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (Get.isRegistered<AlertController>() &&
        Get.find<AlertController>().isActive.value) {
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('alerts')
          .where('senderId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      for (final d in snap.docs) {
        await d.reference.update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> startAlert() async {
    if (isActive.value) return;

    warning.value = null;
    alertSynced.value = false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      warning.value = 'You are signed out, so the alert could not be sent.';
      return;
    }

    final notifiedNames = <String>[];
    final notifiedUserIds = <String>[];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trustedContacts')
          .where('isNotified', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final linkedUserId = data['linkedUserId'] as String?;
        if (name.isNotEmpty) notifiedNames.add(name);
        if (linkedUserId != null && linkedUserId.isNotEmpty) {
          notifiedUserIds.add(linkedUserId);
        }
      }
    } catch (_) {
      warning.value = 'Could not load your trusted contacts.';
    }

    final docRef = FirebaseFirestore.instance.collection('alerts').doc();
    alertId.value = docRef.id;
    reachableContacts.value = notifiedUserIds.length;
    isActive.value = true;
    elapsedSeconds.value = 0;

    await docRef
        .set({
          'senderId': uid,
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
          'notifiedNames': notifiedNames,
          'notifiedUserIds': notifiedUserIds,
          'location': null,
        })
        .then((_) {
          alertSynced.value = true;
          unawaited(_callRahbar({'action': 'send-sos', 'alertId': docRef.id}));
        })
        .catchError((_) {
          warning.value = 'Could not send the alert. Check your connection.';
        });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });

    unawaited(_startLocationTracking(docRef));
    _videoLoopFuture = _startVideoClipLoop(docRef);
    unawaited(_videoLoopFuture!);
  }

  // ------------------------------------------------------------------
  // Location
  // ------------------------------------------------------------------

  void _publishPosition(
    DocumentReference<Map<String, dynamic>> docRef,
    Position position,
  ) {
    currentPosition.value = position;
    docRef
        .update({
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        })
        .catchError((_) {});
  }

  Future<void> _startLocationTracking(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) {
      warning.value =
          'Location permission is off, so your contacts are alerted but '
          'cannot see where you are.';
      return;
    }

    // If location services are off, try to show Android's native
    // "Turn on Location" popup right here in the app -- no navigating
    // to Settings needed. On iOS, Apple does not allow this dialog at
    // all; requestService() there can only fall back to telling the
    // person to enable it manually in Settings, and returns false.
    final locationService = loc.Location();
    bool serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
    }
    if (!serviceEnabled) {
      warning.value =
          'Location services are turned off. Please turn them on to '
          'share your location.';
      return;
    }

    try {
      final first = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      _publishPosition(docRef, first);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _publishPosition(docRef, last);
      } catch (_) {}
    }

    if (!isActive.value) return;

    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'SOS active',
              notificationText:
                  'Sharing your live location with trusted contacts',
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.other,
            distanceFilter: 10,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) => _publishPosition(docRef, position));
  }

  // ------------------------------------------------------------------
  // Video
  // ------------------------------------------------------------------

  Future<bool> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      _cameraController = controller;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    try {
      await controller?.dispose();
    } catch (_) {}
  }

  Future<void> _startVideoClipLoop(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    _videoLoopRunning = true;
    try {
      while (_videoLoopRunning) {
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          final ok = await _initCamera();
          if (!ok) {
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
        }

        try {
          isRecordingClip.value = true;
          final startSecond = elapsedSeconds.value;
          await _cameraController!.startVideoRecording();

          for (
            var i = 0;
            i < _clipDuration.inSeconds && _videoLoopRunning;
            i++
          ) {
            await Future.delayed(const Duration(seconds: 1));
          }

          // Runs even when stopAlert() interrupted the wait above, so
          // the partial clip is saved rather than lost.
          final file = await _cameraController!.stopVideoRecording();
          final stopSecond = elapsedSeconds.value;
          isRecordingClip.value = false;
          unawaited(_saveAndUploadClip(docRef, file, startSecond, stopSecond));
        } catch (_) {
          isRecordingClip.value = false;
          await _disposeCamera();
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } finally {
      isRecordingClip.value = false;
      await _disposeCamera();
    }
  }

  // Saves the clip to local device storage FIRST (so it shows up in
  // RecordedEvidenceScreen immediately, even if the upload below fails
  // or there's no signal), then uploads that same local file to
  // Supabase from a stable path. startElapsedSeconds/stopElapsedSeconds
  // are the EXACT values this controller's own live counter showed
  // while this clip was recording -- passed straight through to local
  // storage so the evidence screen can show the same numbers later.
  Future<void> _saveAndUploadClip(
    DocumentReference<Map<String, dynamic>> docRef,
    XFile file,
    int startElapsedSeconds,
    int stopElapsedSeconds,
  ) async {
    final localEvidence = await EvidenceRecorderService.instance
        .saveVideoClipLocally(
          file,
          startElapsedSeconds: startElapsedSeconds,
          stopElapsedSeconds: stopElapsedSeconds,
        )
        .catchError((_) => null);
    final localPath = localEvidence?.path ?? file.path;

    try {
      final clipId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = '$clipId.mp4';

      final urlResult = await _callRahbar({
        'action': 'upload-url',
        'alertId': docRef.id,
        'fileName': fileName,
      });
      final remotePath = urlResult?['path'] as String?;
      final token = urlResult?['token'] as String?;
      if (remotePath == null || token == null) {
        // No signal / server issue -- the clip is still safe locally,
        // it just isn't visible to contacts yet.
        return;
      }

      await Supabase.instance.client.storage
          .from('evidence')
          .uploadToSignedUrl(remotePath, token, File(localPath));

      await docRef.collection('clips').doc(clipId).set({
        'path': remotePath, // fetch a playback URL via "clip-url" later
        'capturedAt': FieldValue.serverTimestamp(),
      });

      clipsUploaded.value++;
    } catch (_) {
      // Upload failed -- local copy is still safe, move on to the
      // next clip rather than blocking the loop.
    }
  }

  // ------------------------------------------------------------------
  // Stop
  // ------------------------------------------------------------------

  Future<void> stopAlert() async {
    final id = alertId.value;

    _positionSub?.cancel();
    _positionSub = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    isActive.value = false;

    if (id.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(id)
          .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()})
          // Wait at most 5 seconds for the server. On a slow network the
          // write stays queued on the phone and is delivered when it
          // reconnects; the End button must never hang waiting for it.
          .timeout(const Duration(seconds: 5), onTimeout: () {})
          .catchError((_) {});
    }

    _videoLoopRunning = false;
    final loop = _videoLoopFuture;
    _videoLoopFuture = null;
    if (loop != null) {
      await loop.timeout(const Duration(seconds: 8), onTimeout: () {});
    }

    alertId.value = '';
    currentPosition.value = null;
    elapsedSeconds.value = 0;
    clipsUploaded.value = 0;
    alertSynced.value = false;
    reachableContacts.value = 0;
    warning.value = null;
  }

  String get formattedElapsed {
    final m = (elapsedSeconds.value ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds.value % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void onClose() {
    _positionSub?.cancel();
    _elapsedTimer?.cancel();
    _videoLoopRunning = false;
    super.onClose();
  }
}
