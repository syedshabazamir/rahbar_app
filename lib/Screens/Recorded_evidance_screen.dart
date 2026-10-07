import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/model/Evidance_model.dart';
import 'package:rahbar_app/servives/Evidance_recorder_service.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/Screens/Video_Playback_Screen.dart';

/// Shows evidence (photo / audio / video) actually captured and saved
/// on-device during an SOS alert.
class RecordedEvidenceScreen extends StatefulWidget {
  const RecordedEvidenceScreen({super.key});

  @override
  State<RecordedEvidenceScreen> createState() => _RecordedEvidenceScreenState();
}

class _RecordedEvidenceScreenState extends State<RecordedEvidenceScreen> {
  List<EvidenceFile> _evidence = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    setState(() => _isLoading = true);
    final items = await EvidenceRecorderService.instance.getSavedEvidence();
    if (!mounted) return;
    setState(() {
      _evidence = items;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(EvidenceFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this item?',
          style: TextStyle(color: AppColors.title, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${file.label} will be permanently removed from this device.',
          style: const TextStyle(color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.subtitle),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFF9B2C3A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removedIndex = _evidence.indexOf(file);
    setState(() => _evidence.remove(file));

    try {
      await EvidenceRecorderService.instance.deleteEvidence(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _evidence.insert(removedIndex, file));
      Get.snackbar(
        'Could not delete item',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF9B2C3A),
        colorText: Colors.white,
      );
    }
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
                  _evidence.isEmpty
                      ? subtitleText
                      : '$subtitleText · Hold an item to delete',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitle,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _evidence.isEmpty
                    ? const Center(
                        child: Text(
                          'No evidence captured yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.subtitle,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvidence,
                        child: ListView.separated(
                          itemCount: _evidence.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _evidence[index];
                            switch (item.type) {
                              case EvidenceType.audio:
                                return _AudioEvidenceTile(
                                  file: item,
                                  onDelete: () => _deleteItem(item),
                                );
                              case EvidenceType.video:
                                return _VideoEvidenceTile(
                                  file: item,
                                  onDelete: () => _deleteItem(item),
                                );
                              case EvidenceType.photo:
                                return _PhotoEvidenceTile(
                                  file: item,
                                  onDelete: () => _deleteItem(item),
                                );
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceTileShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _EvidenceTileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
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
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.subtitle,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(EvidenceFile file) {
  final range = file.elapsedRangeLabel;
  if (range != null) return range;

  final dt = file.capturedAt;
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

class _PhotoEvidenceTile extends StatelessWidget {
  final EvidenceFile file;
  final VoidCallback onDelete;

  const _PhotoEvidenceTile({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _EvidenceTileShell(
      icon: Icons.photo_camera_outlined,
      title: file.label,
      subtitle: _formatTime(file),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subtitle),
      onDelete: onDelete,
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
  final VoidCallback onDelete;

  const _VideoEvidenceTile({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _EvidenceTileShell(
      icon: Icons.videocam_outlined,
      title: file.label,
      subtitle: _formatTime(file),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subtitle),
      onDelete: onDelete,
      onTap: () => Get.to(() => VideoPlaybackScreen(path: file.path)),
    );
  }
}

class _AudioEvidenceTile extends StatefulWidget {
  final EvidenceFile file;
  final VoidCallback onDelete;

  const _AudioEvidenceTile({required this.file, required this.onDelete});

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
      subtitle: _formatTime(widget.file),
      onDelete: widget.onDelete,
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
