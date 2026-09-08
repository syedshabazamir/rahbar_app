import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rahbar_app/model/Evidance_model.dart';
import 'package:record/record.dart';

/// Handles capturing and saving real evidence (photo, audio, video) to
/// local device storage when an SOS alert is triggered.
///
/// Usage (e.g. from wherever your SOS button lives):
/// ```dart
/// await EvidenceRecorderService.instance.captureSosEvidence();
/// ```
///
/// NOTE: This saves files locally under the app's documents directory,
/// in an `evidence/` subfolder. Uploading these files to your backend
/// (so a trusted contact can view them remotely) is a separate step —
/// see the TODO in `_uploadIfNeeded()`.
class EvidenceRecorderService {
  EvidenceRecorderService._();
  static final EvidenceRecorderService instance = EvidenceRecorderService._();

  CameraController? _cameraController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;

  Future<Directory> _evidenceDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/evidence');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _ensureCameraReady() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No cameras available on this device.');
    }
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await _cameraController!.initialize();
  }

  /// Captures a photo, a short audio clip, and a short video clip in
  /// sequence, and saves all three to the evidence folder. Call this
  /// as soon as an SOS alert is triggered.
  ///
  /// Runs one capture at a time (rather than simultaneously) since the
  /// camera and standalone mic recording both need exclusive access to
  /// the microphone on most devices.
  Future<List<EvidenceFile>> captureSosEvidence({
    Duration audioDuration = const Duration(seconds: 15),
    Duration videoDuration = const Duration(seconds: 10),
  }) async {
    if (_isCapturing) {
      // Already capturing — avoid overlapping captures.
      return getSavedEvidence();
    }
    _isCapturing = true;
    final captured = <EvidenceFile>[];

    try {
      final granted = await _requestPermissions();
      if (!granted) {
        throw StateError('Camera/microphone permission not granted.');
      }

      await _ensureCameraReady();

      final photoPath = await _capturePhoto();
      captured.add(EvidenceFile.fromPath(photoPath));

      final audioPath = await _recordAudioClip(audioDuration);
      if (audioPath != null) {
        captured.add(EvidenceFile.fromPath(audioPath));
      }

      final videoPath = await _recordVideoClip(videoDuration);
      captured.add(EvidenceFile.fromPath(videoPath));

      // TODO: upload `captured` files to your backend here so a trusted
      // contact can view them remotely via LiveEvidenceScreen without
      // needing the affected user's device.
    } finally {
      _isCapturing = false;
    }

    return captured;
  }

  Future<String> _capturePhoto() async {
    final xfile = await _cameraController!.takePicture();
    final dir = await _evidenceDir();
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${dir.path}/$fileName';
    await File(xfile.path).copy(savedPath);
    return savedPath;
  }

  Future<String?> _recordAudioClip(Duration duration) async {
    if (!await _audioRecorder.hasPermission()) return null;

    final dir = await _evidenceDir();
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${dir.path}/$fileName';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    await Future.delayed(duration);
    await _audioRecorder.stop();
    return path;
  }

  Future<String> _recordVideoClip(Duration duration) async {
    await _cameraController!.startVideoRecording();
    await Future.delayed(duration);
    final xfile = await _cameraController!.stopVideoRecording();

    final dir = await _evidenceDir();
    final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final savedPath = '${dir.path}/$fileName';
    await File(xfile.path).copy(savedPath);
    return savedPath;
  }

  /// Returns all evidence currently saved on this device, newest first.
  Future<List<EvidenceFile>> getSavedEvidence() async {
    final dir = await _evidenceDir();
    if (!await dir.exists()) return [];

    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files.map((f) => EvidenceFile.fromPath(f.path)).toList();
  }

  /// Releases the camera. Call this when the capturing flow / SOS
  /// screen is disposed to free the camera for other use.
  Future<void> dispose() async {
    await _cameraController?.dispose();
    _cameraController = null;
  }
}
