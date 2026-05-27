import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SmartMedia extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final String? thumbnailUrl;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SmartMedia({
  super.key,
  required this.url,
  this.thumbnailUrl, // ✅ اضافه کن
  this.fit = BoxFit.cover,
  this.borderRadius,
  this.width,
  this.height,
  this.errorBuilder,
});

  @override
  State<SmartMedia> createState() => _SmartMediaState();
}

class _SmartMediaState extends State<SmartMedia> {
  static final Map<String, Uint8List> _memoryCache = {};

  Uint8List? _thumbnail;
  bool _loading = false;

  bool _isVideo(String url) {
    final u = Uri.decodeFull(url).toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.hevc') ||
        u.contains('.webm');
  }

  @override
  void initState() {
    super.initState();

    if (_isVideo(widget.url)) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
  final url = widget.url;

  if (_memoryCache.containsKey(url)) {
    setState(() {
      _thumbnail = _memoryCache[url];
    });
    return;
  }

  setState(() => _loading = true);

  try {
    final cacheManager = DefaultCacheManager();
    final file = await cacheManager.getFileStream(url).first;

    if (file is FileInfo) {
      final path = file.file.path;

      final data = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 70,
      ).timeout(const Duration(seconds: 3));

      if (data != null) {
        _memoryCache[url] = data;

        if (mounted) {
          setState(() {
            _thumbnail = data;
          });
        }
      }
    }
  } catch (e) {
    debugPrint("❌ THUMBNAIL ERROR: $e");
  } finally {
    if (mounted) {
      setState(() {
        _loading = false; // 🔥 همیشه خاموش میشه
      });
    }
  }
}
  @override
Widget build(BuildContext context) {
  final isVideo = _isVideo(widget.url);

  Widget content;

  if (isVideo) {
    content = Stack(
      fit: StackFit.expand,
      children: [
        if (_thumbnail != null)
          Image.memory(
            _thumbnail!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
          )
        else if (_loading)
          Container(
            color: Colors.grey.shade300,
          )
        else
          Container(
            color: Colors.grey.shade400,
            child: const Center(
              child: Icon(
                Icons.videocam,
                color: Colors.white70,
                size: 32,
              ),
            ),
          ),

        Container(
          color: Colors.black.withOpacity(0.25),
        ),

        const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 42,
          ),
        ),
      ],
    );
  } else {
    content = Image.network(
      widget.url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: widget.errorBuilder ??
          (_, __, ___) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.broken_image),
                ),
              ),
    );
  }

  final wrapped = widget.borderRadius != null
      ? ClipRRect(
          borderRadius: widget.borderRadius!,
          child: content,
        )
      : content;

  return SizedBox(
    width: widget.width,
    height: widget.height,
    child: wrapped,
  );
}
}
