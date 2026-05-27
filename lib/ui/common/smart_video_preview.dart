import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class SmartVideoPreview extends StatefulWidget {
  final String videoUrl;
  final String? thumbnail;

  const SmartVideoPreview({super.key, required this.videoUrl, this.thumbnail});

  @override
  State<SmartVideoPreview> createState() => _SmartVideoPreviewState();
}

class _SmartVideoPreviewState extends State<SmartVideoPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _visible = false;

  Future<void> _init() async {
    if (_controller != null) return;

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0); // 🔇 مهم

      _initialized = true;

      if (_visible) {
        await controller.play();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("❌ video init error: $e");
    }
  }

  Future<void> _disposeVideo() async {
    await _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  void _onVisibilityChanged(VisibilityInfo info) async {
    final visibleFraction = info.visibleFraction;

    if (visibleFraction > 0.6) {
      _visible = true;

      await _init();

      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.play();
      }
    } else {
      _visible = false;

      if (_controller != null && _controller!.value.isPlaying) {
        await _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🎬 VIDEO
          if (_controller != null && _initialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          // 🖼 THUMBNAIL
          else if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
            Image.network(widget.thumbnail!, fit: BoxFit.cover)
          // fallback
          else
            Container(color: Colors.black87),

          // ▶ overlay
          const Positioned(
            child: Icon(Icons.volume_off, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
