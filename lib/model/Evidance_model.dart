import 'dart:io';

enum EvidenceType { photo, audio, video }

/// Represents a single piece of evidence (photo/audio/video) saved on disk
/// during an SOS alert.
class EvidenceFile {
  final String path;
  final EvidenceType type;
  final DateTime capturedAt;

  EvidenceFile({
    required this.path,
    required this.type,
    required this.capturedAt,
  });

  /// Builds an [EvidenceFile] from a saved path. Expects file names of the
  /// form `photo_<millis>.jpg`, `audio_<millis>.m4a`, `video_<millis>.mp4`
  /// (see EvidenceRecorderService), but falls back to the file's modified
  /// timestamp if the name doesn't match that pattern.
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

    final match = RegExp(r'_(\d+)\.').firstMatch(fileName);
    final millis = match != null ? int.tryParse(match.group(1)!) : null;
    final capturedAt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis)
        : File(path).statSync().modified;

    return EvidenceFile(path: path, type: type, capturedAt: capturedAt);
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
