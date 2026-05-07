import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_item.dart';

class GalleryViewerPage extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const GalleryViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  bool _showUI = true;

  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<int> _videoInitFailed = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _preloadAround(_currentIndex);
      await _playCurrentIfNeeded();
    });
  }

  bool _isVideo(MediaItem item) => item.type == MediaType.video;

  Future<void> _preloadAround(int index) async {
    for (int i = index - 1; i <= index + 1; i++) {
      if (i < 0 || i >= widget.items.length) continue;

      final item = widget.items[i];

      if (_isVideo(item)) {
        await _initVideo(i, item.url, autoPlay: i == _currentIndex);
      } else {
        final uri = Uri.tryParse(item.url);
        if (uri != null &&
            uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https')) {
          try {
            await precacheImage(NetworkImage(item.url), context);
          } catch (_) {}
        }
      }
    }

    _disposeFarControllers(index);
  }

  Future<void> _initVideo(
    int index,
    String url, {
    bool autoPlay = false,
  }) async {
    if (_videoControllers.containsKey(index)) {
      final existing = _videoControllers[index]!;
      if (autoPlay && existing.value.isInitialized && !existing.value.isPlaying) {
        await existing.play();
        if (mounted) setState(() {});
      }
      return;
    }

    if (_videoInitFailed.contains(index)) return;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        throw Exception("Invalid video url");
      }

      final controller = VideoPlayerController.networkUrl(uri);
      _videoControllers[index] = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception("Video init timeout"),
      );

      await controller.setLooping(true);

      if (autoPlay) {
        await controller.play();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("❌ VIDEO INIT ERROR [$index]: $e");
      _videoControllers[index]?.dispose();
      _videoControllers.remove(index);
      _videoInitFailed.add(index);

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _pauseAllVideos() async {
    for (final controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  Future<void> _playCurrentIfNeeded() async {
    final item = widget.items[_currentIndex];
    if (!_isVideo(item)) return;

    await _initVideo(_currentIndex, item.url, autoPlay: true);
  }

  void _disposeFarControllers(int currentIndex) {
    final keysToRemove = _videoControllers.keys
        .where((i) => (i - currentIndex).abs() > 1)
        .toList();

    for (final key in keysToRemove) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
    }
  }

  Future<void> _handlePageChanged(int index) async {
    await _pauseAllVideos();

    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });

    await _preloadAround(index);
    await _playCurrentIfNeeded();
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showUI = !_showUI;
              });
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (_, index) {
                final item = widget.items[index];

                if (!_isVideo(item)) {
                  return Center(
                    child: Hero(
                      tag: "media_${item.url}_$index",
                      child: _ZoomableImage(url: item.url),
                    ),
                  );
                }

                final controller = _videoControllers[index];

                if (_videoInitFailed.contains(index)) {
                  return _VideoErrorView(url: item.url);
                }

                if (controller == null || !controller.value.isInitialized) {
                  return _VideoLoadingView(url: item.url);
                }

                final isPlaying = controller.value.isPlaying;

                return Center(
                  child: GestureDetector(
                    onTap: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await _pauseAllVideos();
                        await controller.play();
                      }

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(controller),
                            if (!isPlaying)
                              const Icon(
                                Icons.play_circle_fill,
                                size: 72,
                                color: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_showUI)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (_showUI)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoLoadingView extends StatelessWidget {
  final String url;

  const _VideoLoadingView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _VideoErrorView extends StatelessWidget {
  final String url;

  const _VideoErrorView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Icon(
        Icons.videocam_off,
        color: Colors.white54,
        size: 56,
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;

  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) {
        _doubleTapDetails = details;
      },
      onDoubleTap: () {
        final position = _doubleTapDetails?.localPosition;
        if (position == null) return;

        final zoomed = _controller.value.getMaxScaleOnAxis() > 1;

        if (zoomed) {
          _controller.value = Matrix4.identity();
        } else {
          const zoom = 3.0;
          _controller.value = Matrix4.identity()
            ..translate(-position.dx * (zoom - 1), -position.dy * (zoom - 1))
            ..scale(zoom);
        }
      },
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 56,
          ),
        ),
      ),
    );
  }
}