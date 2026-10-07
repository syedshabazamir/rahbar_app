import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:rahbar_app/model/Evidance_model.dart';

/// Handles LOCAL storage of evidence (photo/audio/video) captured
/// during an SOS alert.
///
/// This service no longer owns a CameraController -- AlertController
/// is the single owner of the camera during an active alert (only one
/// process can hold the camera at a time), and hands finished clips
/// here just to be copied into the local evidence/ folder so they
/// show up in RecordedEvidenceScreen.
class EvidenceRecorderService {
  EvidenceRecorderService._();
  static final EvidenceRecorderService instance = EvidenceRecorderService._();

  // Kept available for a scenario where you want PURE audio evidence
  // with no video. NOT safe to run at the same time as AlertController's
  // camera recording -- most devices only allow one process to hold the
  // microphone at once, and the camera's video already records audio.
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<Directory> _evidenceDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/evidence');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a just-recorded video clip (an XFile from
  /// CameraController.stopVideoRecording()) into the local evidence
  /// folder. Returns the EvidenceFile so callers can also upload from
  /// this same stable local path.
  ///
  /// [startElapsedSeconds] / [stopElapsedSeconds], if given, are the
  /// EXACT values AlertController's live "Active · 00:04" counter
  /// showed when this clip started/stopped recording -- encoded into
  /// the filename so RecordedEvidenceScreen can show those same
  /// numbers back later, even after the app restarts.
  Future<EvidenceFile> saveVideoClipLocally(
    XFile clip, {
    int? startElapsedSeconds,
    int? stopElapsedSeconds,
  }) async {
    final dir = await _evidenceDir();
    final capturedMillis = DateTime.now().millisecondsSinceEpoch;
    final fileName = (startElapsedSeconds != null && stopElapsedSeconds != null)
        ? 'video_${capturedMillis}_${startElapsedSeconds}_$stopElapsedSeconds.mp4'
        : 'video_$capturedMillis.mp4';
    final savedPath = '${dir.path}/$fileName';
    await File(clip.path).copy(savedPath);
    return EvidenceFile.fromPath(savedPath);
  }

  /// Copies a just-taken photo (an XFile from
  /// CameraController.takePicture()) into the local evidence folder.
  /// NOTE: this is currently local-only -- the Supabase "evidence"
  /// bucket only accepts video/mp4 right now, so photos are not
  /// uploaded for contacts to see yet.
  Future<EvidenceFile> savePhotoLocally(XFile photo) async {
    final dir = await _evidenceDir();
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${dir.path}/$fileName';
    await File(photo.path).copy(savedPath);
    return EvidenceFile.fromPath(savedPath);
  }

  /// Standalone microphone-only recording -- see the class doc comment
  /// for why this should not be called while AlertController's camera
  /// loop is also running.
  Future<EvidenceFile?> recordAudioClip(Duration duration) async {
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
    return EvidenceFile.fromPath(path);
  }

  /// Returns all evidence currently saved on this device, newest first.
  /// This is what RecordedEvidenceScreen reads -- video clips saved via
  /// saveVideoClipLocally() during an SOS show up here automatically.
  Future<List<EvidenceFile>> getSavedEvidence() async {
    final dir = await _evidenceDir();
    if (!await dir.exists()) return [];

    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files.map((f) => EvidenceFile.fromPath(f.path)).toList();
  }

  /// Deletes one saved evidence file from local storage by its path.
  /// Used by RecordedEvidenceScreen when the person removes an item.
  Future<void> deleteEvidence(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
