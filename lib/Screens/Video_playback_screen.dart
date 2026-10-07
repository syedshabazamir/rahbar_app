import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:rahbar_app/utils/App_colors.dart';

/// Full-screen playback for a recorded video evidence clip.
class VideoPlaybackScreen extends StatefulWidget {
  final String path;

  const VideoPlaybackScreen({super.key, required this.path});

  @override
  State<VideoPlaybackScreen> createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // lets the video sit behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _ready
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              // Fills the entire available area (edge-to-edge, like a
              // native video player) instead of the previous
              // Center + AspectRatio, which let the video shrink to
              // fit and left black letterbox bars around it on most
              // phone aspect ratios. BoxFit.cover scales the video up
              // to fill the screen, cropping any overflow -- same
              // behavior as Instagram/TikTok-style video viewers.
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      floatingActionButton: _ready
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryPurple,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
