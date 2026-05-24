import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:barky_matches_fixed/social/models/social_post.dart';
import 'package:barky_matches_fixed/social/services/post_save_service.dart';
import 'package:barky_matches_fixed/social/services/social_post_service.dart';
import 'package:barky_matches_fixed/social/widgets/comments_bottom_sheet.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class SocialPostMediaViewerOverlay extends StatefulWidget {
  final List<SocialPost> posts;
  final int initialPostIndex;
  final int initialMediaIndex;
  final VoidCallback onClose;

  const SocialPostMediaViewerOverlay({
    super.key,
    required this.posts,
    required this.initialPostIndex,
    required this.initialMediaIndex,
    required this.onClose,
  });

  @override
  State<SocialPostMediaViewerOverlay> createState() =>
      _SocialPostMediaViewerOverlayState();
}

class _SocialPostMediaViewerOverlayState
    extends State<SocialPostMediaViewerOverlay> {
  final SocialPostService _postService = SocialPostService();
  final PostSaveService _saveService = PostSaveService();
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<int> _failedVideoIndexes = {};
  late final PageController _controller;
  late final List<_ViewerMediaItem> _items;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _items = _flattenItems(widget.posts);
    _index = _resolveInitialIndex();
    _controller = PageController(initialPage: _index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareCurrentMedia();
    });
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _controller.dispose();
    super.dispose();
  }

  List<_ViewerMediaItem> _flattenItems(List<SocialPost> posts) {
    final items = <_ViewerMediaItem>[];

    for (var postIndex = 0; postIndex < posts.length; postIndex++) {
      final post = posts[postIndex];
      final media = post.media.isNotEmpty
          ? post.media
          : post.mediaUrls
                .map(
                  (url) => SocialPostMedia(
                    url: url,
                    type: post.mediaType == 'video' ? 'video' : 'image',
                  ),
                )
                .toList();

      for (var mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
        items.add(
          _ViewerMediaItem(
            postIndex: postIndex,
            mediaIndex: mediaIndex,
            post: post,
            media: media[mediaIndex],
          ),
        );
      }
    }

    return items;
  }

  int _resolveInitialIndex() {
    if (_items.isEmpty) return 0;

    final resolved = _items.indexWhere(
      (item) =>
          item.postIndex == widget.initialPostIndex &&
          item.mediaIndex == widget.initialMediaIndex,
    );

    if (resolved >= 0) return resolved;
    return 0;
  }

  Future<void> _prepareCurrentMedia() async {
    await _pauseAllVideos();
    _disposeFarVideos();

    if (_items.isEmpty) return;
    final item = _items[_index];

    if (item.media.isVideo) {
      await _initVideo(_index, item.media.url, autoPlay: true);
    }

    _precacheAdjacentImages();
  }

  Future<void> _initVideo(
    int index,
    String url, {
    bool autoPlay = false,
  }) async {
    if (_videoControllers.containsKey(index)) {
      final controller = _videoControllers[index]!;
      if (autoPlay && controller.value.isInitialized) {
        await controller.play();
      }
      return;
    }

    if (_failedVideoIndexes.contains(index)) return;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        throw Exception('Invalid video url');
      }

      final controller = VideoPlayerController.networkUrl(uri);
      _videoControllers[index] = controller;

      await controller.initialize().timeout(const Duration(seconds: 12));
      await controller.setLooping(true);

      if (autoPlay) {
        await controller.play();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Petplore viewer video init error: $e');
      await _videoControllers[index]?.dispose();
      _videoControllers.remove(index);
      _failedVideoIndexes.add(index);
      if (mounted) setState(() {});
    }
  }

  Future<void> _pauseAllVideos() async {
    for (final controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  void _disposeFarVideos() {
    final keys = _videoControllers.keys
        .where((key) => (key - _index).abs() > 1)
        .toList();

    for (final key in keys) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
    }
  }

  void _precacheAdjacentImages() {
    for (var i = _index - 1; i <= _index + 1; i++) {
      if (i < 0 || i >= _items.length) continue;
      final media = _items[i].media;
      if (!media.isVideo && media.url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(media.url), context);
      }
    }
  }

  Future<void> _handlePageChanged(int index) async {
    setState(() {
      _index = index;
    });

    await _prepareCurrentMedia();
  }

  Future<void> _sharePost(SocialPost post) async {
    try {
      final box = context.findRenderObject() as RenderBox?;

      await Share.share(
        '''
🐾 Seen on PetSupo

${post.caption}

https://petsupo.com/post/${post.id}
''',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );

      await _postService.incrementShareCount(post.id);
    } catch (e) {
      debugPrint('Petplore viewer share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Material(
        color: Colors.black,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(LucideIcons.x, color: Colors.white),
            ),
          ),
        ),
      );
    }

    final current = _items[_index];
    final post = current.post;

    return Material(
      color: Colors.black.withValues(alpha: 0.98),
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) {
                return _ViewerMedia(
                  item: _items[index],
                  controller: _videoControllers[index],
                  videoFailed: _failedVideoIndexes.contains(index),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
            if (_items.length > 1)
              Positioned(
                top: 18,
                right: 18,
                child: _ViewerCounter(index: _index + 1, count: _items.length),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _ViewerBottomBar(
                post: post,
                onLike: () => _postService.toggleLike(post.id),
                onComment: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsBottomSheet(post: post),
                  );
                },
                onShare: () => _sharePost(post),
                onSave: () => _saveService.toggleSave(post.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerMediaItem {
  final int postIndex;
  final int mediaIndex;
  final SocialPost post;
  final SocialPostMedia media;

  const _ViewerMediaItem({
    required this.postIndex,
    required this.mediaIndex,
    required this.post,
    required this.media,
  });
}

class _ViewerMedia extends StatelessWidget {
  final _ViewerMediaItem item;
  final VideoPlayerController? controller;
  final bool videoFailed;

  const _ViewerMedia({
    required this.item,
    required this.controller,
    required this.videoFailed,
  });

  @override
  Widget build(BuildContext context) {
    final media = item.media;

    if (media.isVideo) {
      if (controller != null && controller!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: VideoPlayer(controller!),
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: media.thumbnailUrl!,
              fit: BoxFit.contain,
            )
          else
            Container(color: Colors.black),
          Center(
            child: Icon(
              videoFailed ? LucideIcons.videoOff : LucideIcons.playCircle,
              color: Colors.white,
              size: 70,
            ),
          ),
        ],
      );
    }

    return Center(
      child: CachedNetworkImage(
        imageUrl: media.url,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (context, url, error) =>
            const Icon(LucideIcons.imageOff, color: Colors.white38, size: 54),
      ),
    );
  }
}

class _ViewerCounter extends StatelessWidget {
  final int index;
  final int count;

  const _ViewerCounter({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$index / $count',
        style: AppTheme.caption(color: Colors.white, weight: FontWeight.w800),
      ),
    );
  }
}

class _ViewerBottomBar extends StatelessWidget {
  final SocialPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const _ViewerBottomBar({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.caption.isNotEmpty)
            Text(
              post.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ViewerAction(
                icon: LucideIcons.heart,
                label: post.likeCount.toString(),
                onTap: onLike,
              ),
              const SizedBox(width: 18),
              _ViewerAction(
                icon: LucideIcons.messageCircle,
                label: post.commentCount.toString(),
                onTap: onComment,
              ),
              const SizedBox(width: 18),
              _ViewerAction(
                icon: LucideIcons.send,
                label: post.shareCount.toString(),
                onTap: onShare,
              ),
              const Spacer(),
              _ViewerAction(
                icon: LucideIcons.bookmark,
                label: 'Save',
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption(
              color: Colors.white,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
