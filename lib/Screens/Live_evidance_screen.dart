import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

/// Shows the real evidence clips recorded during an SOS, fetched from
/// alerts/{alertId}/clips. Each clip's storage `path` is private
/// (Supabase bucket has no public URLs), so playback goes through the
/// `clip-url` Edge Function action, which checks the caller is either
/// the alert's sender or one of its notifiedUserIds before handing
/// out a short-lived signed URL.
class LiveEvidenceScreen extends StatefulWidget {
  const LiveEvidenceScreen({super.key});

  @override
  State<LiveEvidenceScreen> createState() => _LiveEvidenceScreenState();
}

class _LiveEvidenceScreenState extends State<LiveEvidenceScreen> {
  String? _alertId;
  String _firstName = 'them';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = Get.arguments;
    _alertId = (args is Map ? args['alertId'] : null)?.toString();
    final name = (args is Map ? args['name'] : null)?.toString() ?? 'them';
    _firstName = name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final alertId = _alertId;
    if (alertId == null || alertId.isEmpty) {
      return const _Shell(
        child: Center(
          child: Text(
            'This evidence link is invalid.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return _Shell(
      title: 'Evidence',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .doc(alertId)
            .collection('clips')
            .orderBy('capturedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No clips from $_firstName's phone yet.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final path = data['path'] as String?;
              final capturedAt = (data['capturedAt'] as Timestamp?)?.toDate();
              if (path == null) return const SizedBox.shrink();

              return _ClipTile(
                path: path,
                capturedAt: capturedAt,
                clipNumber: docs.length - index,
              );
            },
          );
        },
      ),
    );
  }
}

/// One clip row: thumbnail-less card (no thumbnail generation set up)
/// that expands into an inline player when tapped.
class _ClipTile extends StatefulWidget {
  final String path;
  final DateTime? capturedAt;
  final int clipNumber;

  const _ClipTile({
    required this.path,
    required this.capturedAt,
    required this.clipNumber,
  });

  @override
  State<_ClipTile> createState() => _ClipTileState();
}

class _ClipTileState extends State<_ClipTile> {
  VideoPlayerController? _controller;
  bool _isLoading = false;
  String? _error;

  Future<void> _play() async {
    if (_controller != null) {
      setState(() {}); // already loaded -- build() below toggles play/pause
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) throw Exception('Not signed in');

      final res = await Supabase.instance.client.functions.invoke(
        'rahbar',
        headers: {'x-firebase-token': idToken},
        body: {'action': 'clip-url', 'path': widget.path},
      );

      final url = (res.data as Map?)?['url'] as String?;
      if (url == null) throw Exception('No playback URL returned');

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
      controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load this clip. It may have expired -- try again.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.eveningCard,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white70,
                        size: 48,
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.videocam_outlined,
                          size: 18,
                          color: AppColors.alertDanger,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clip ${widget.clipNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.alertDanger,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          _formatTime(widget.capturedAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (controller == null)
                  TextButton(
                    onPressed: _isLoading ? null : _play,
                    child: const Text('Play'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  final String title;
  final Widget child;

  const _Shell({this.title = 'Evidence', required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.eveningDark,
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
