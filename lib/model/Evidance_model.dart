import 'dart:io';

enum EvidenceType { photo, audio, video }

/// Represents a single piece of evidence (photo/audio/video) saved on disk
/// during an SOS alert.
class EvidenceFile {
  final String path;
  final EvidenceType type;
  final DateTime capturedAt;

  /// The exact elapsed-seconds-since-alert-started values, captured
  /// directly from AlertController's live "Active · 00:04" counter at
  /// the moment this clip started and stopped recording -- so what
  /// you see here is the SAME numbers you saw live during the alert,
  /// not a re-derived estimate. Null for clips saved before this was
  /// tracked, or for photos/audio with no associated alert.
  final int? startElapsedSeconds;
  final int? stopElapsedSeconds;

  EvidenceFile({
    required this.path,
    required this.type,
    required this.capturedAt,
    this.startElapsedSeconds,
    this.stopElapsedSeconds,
  });

  bool get hasElapsedRange =>
      startElapsedSeconds != null && stopElapsedSeconds != null;

  static String _mmss(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// "00:04 - 00:24", matching the exact mm:ss format shown live
  /// during recording. Null if the range isn't known for this file.
  String? get elapsedRangeLabel => hasElapsedRange
      ? '${_mmss(startElapsedSeconds!)} - ${_mmss(stopElapsedSeconds!)}'
      : null;

  /// Builds an [EvidenceFile] from a saved path. Expects file names of
  /// the form:
  ///   photo_<capturedMillis>.jpg
  ///   audio_<capturedMillis>.m4a
  ///   video_<capturedMillis>.mp4
  ///   video_<capturedMillis>_<startSeconds>_<stopSeconds>.mp4   (new
  ///     format -- the two extra numbers are optional and backward-
  ///     compatible: older files without them just get
  ///     startElapsedSeconds/stopElapsedSeconds == null)
  factory EvidenceFile.fromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    EvidenceType type;
    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      type = EvidenceType.photo;
    } else if (['m4a', 'aac', 'mp3', 'wav'].contains(ext)) {
      type = EvidenceType.audio;
    } else {
      type = EvidenceType.video;
    }

    // Matches "_<millis>" (capturedAt) and optionally two more
    // "_<int>" groups (start/stop elapsed seconds) before the
    // extension.
    final match = RegExp(r'_(\d+)(?:_(\d+)_(\d+))?\.').firstMatch(fileName);
    final capturedMillis = match != null ? int.tryParse(match.group(1)!) : null;
    final startSec = match != null ? int.tryParse(match.group(2) ?? '') : null;
    final stopSec = match != null ? int.tryParse(match.group(3) ?? '') : null;

    final capturedAt = capturedMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(capturedMillis)
        : File(path).statSync().modified;

    return EvidenceFile(
      path: path,
      type: type,
      capturedAt: capturedAt,
      startElapsedSeconds: startSec,
      stopElapsedSeconds: stopSec,
    );
  }

  String get label {
    switch (type) {
      case EvidenceType.photo:
        return 'Photo captured';
      case EvidenceType.audio:
        return 'Audio recording';
      case EvidenceType.video:
        return 'Video clip';
    }
  }
}
