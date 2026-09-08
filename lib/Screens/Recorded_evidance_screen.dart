import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/model/Evidance_model.dart';
import 'package:rahbar_app/servives/Evidance_recorder_service.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/Screens/Video_Playback_Screen.dart';

/// Shows evidence (photo / audio / video) actually captured and saved
/// on-device during an SOS alert. Expects arguments: { 'name' } (optional,
/// used only for the header text).
class RecordedEvidenceScreen extends StatefulWidget {
  const RecordedEvidenceScreen({super.key});

  @override
  State<RecordedEvidenceScreen> createState() => _RecordedEvidenceScreenState();
}

class _RecordedEvidenceScreenState extends State<RecordedEvidenceScreen> {
  late Future<List<EvidenceFile>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _evidenceFuture = EvidenceRecorderService.instance.getSavedEvidence();
  }

  Future<void> _refresh() async {
    setState(() {
      _evidenceFuture = EvidenceRecorderService.instance.getSavedEvidence();
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? {};
    final String? name = args['name'];
    final String subtitleText = name != null
        ? 'Captured during $name\'s SOS alert'
        : 'All photos, audio, and video recorded during past alerts';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.title),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Recorded Evidence',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  subtitleText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: FutureBuilder<List<EvidenceFile>>(
                  future: _evidenceFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final evidence = snapshot.data ?? [];
                    if (evidence.isEmpty) {
                      return const Center(
                        child: Text(
                          'No evidence captured yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.subtitle,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        itemCount: evidence.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = evidence[index];
                          switch (item.type) {
                            case EvidenceType.audio:
                              return _AudioEvidenceTile(file: item);
                            case EvidenceType.video:
                              return _VideoEvidenceTile(file: item);
                            case EvidenceType.photo:
                              return _PhotoEvidenceTile(file: item);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared visual shell so photo/audio/video tiles look consistent.
class _EvidenceTileShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _EvidenceTileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primaryPurple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
            trailing,
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _PhotoEvidenceTile extends StatelessWidget {
  final EvidenceFile file;

  const _PhotoEvidenceTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return _EvidenceTileShell(
      icon: Icons.photo_camera_outlined,
      title: file.label,
      subtitle: _formatTime(file.capturedAt),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subtitle),
      onTap: () {
        Get.to(
          () => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: InteractiveViewer(child: Image.file(File(file.path))),
            ),
          ),
        );
      },
    );
  }
}

class _VideoEvidenceTile extends StatelessWidget {
  final EvidenceFile file;

  const _VideoEvidenceTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return _EvidenceTileShell(
      icon: Icons.videocam_outlined,
      title: file.label,
      subtitle: _formatTime(file.capturedAt),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subtitle),
      onTap: () => Get.to(() => VideoPlaybackScreen(path: file.path)),
    );
  }
}

class _AudioEvidenceTile extends StatefulWidget {
  final EvidenceFile file;

  const _AudioEvidenceTile({required this.file});

  @override
  State<_AudioEvidenceTile> createState() => _AudioEvidenceTileState();
}

class _AudioEvidenceTileState extends State<_AudioEvidenceTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.file.path));
    }
    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EvidenceTileShell(
      icon: Icons.mic_none_outlined,
      title: widget.file.label,
      subtitle: _formatTime(widget.file.capturedAt),
      trailing: IconButton(
        icon: Icon(
          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
          color: AppColors.primaryPurple,
          size: 30,
        ),
        onPressed: _toggle,
      ),
    );
  }
}
