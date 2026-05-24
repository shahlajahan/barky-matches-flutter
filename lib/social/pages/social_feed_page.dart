import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:barky_matches_fixed/app_state.dart';
import '../models/social_post.dart';
import '../services/social_post_service.dart';
import '../widgets/comments_bottom_sheet.dart';

import '../services/post_save_service.dart';

import '../widgets/petplore_stories_bar.dart';
import '../widgets/social_post_media_viewer_overlay.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/widgets/ads/native_ad_widget.dart';

class NativeAdMarker {}

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final SocialPostService _postService = SocialPostService();

  final PostSaveService _saveService = PostSaveService();

  String? _animatingPostId;
  SocialPost? _viewerPost;
  int _viewerMediaIndex = 0;

  @override
  Widget build(BuildContext context) {
    debugPrint('🔥 SOCIAL FEED PAGE BUILD');

    return Container(
      color: Colors.black,
      child: StreamBuilder<List<SocialPost>>(
        stream: _postService.streamPublicPosts(),
        builder: (context, snapshot) {
          debugPrint('🔥 FEED SNAPSHOT STATE: ${snapshot.connectionState}');

          debugPrint('🔥 FEED HAS ERROR: ${snapshot.hasError}');

          if (snapshot.hasError) {
            debugPrint('🔥 FEED ERROR: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',

                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final posts = snapshot.data ?? [];

          final List<dynamic> feedItems = [];

          for (int i = 0; i < posts.length; i++) {
            feedItems.add(posts[i]);

            if ((i + 1) % 5 == 0) {
              feedItems.add(NativeAdMarker());
            }
          }

          return Stack(
            children: [
              ListView.builder(
                key: const PageStorageKey('social_feed'),
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: posts.isEmpty ? 2 : feedItems.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const PetploreStoriesBar();
                  }

                  if (posts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No posts yet',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  final item = feedItems[index - 1];

                  if (item is NativeAdMarker) {
                    return const NativeAdWidget();
                  }

                  final post = item as SocialPost;

                  return _buildPostCard(post);
                },
              ),
              if (_viewerPost != null)
                Positioned.fill(
                  child: SocialPostMediaViewerOverlay(
                    posts: [_viewerPost!],
                    initialPostIndex: 0,
                    initialMediaIndex: _viewerMediaIndex,
                    onClose: () {
                      setState(() {
                        _viewerPost = null;
                        _viewerMediaIndex = 0;
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostCard(SocialPost post) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ───────────────── HEADER ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

            child: Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openUserProfile(post),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 2,
                      ),
                    ),

                    child: CircleAvatar(
                      radius: 24,

                      backgroundColor: Colors.white12,

                      backgroundImage: post.userPhotoUrl != null
                          ? CachedNetworkImageProvider(post.userPhotoUrl!)
                          : null,

                      child: post.userPhotoUrl == null
                          ? const Icon(LucideIcons.dog, color: Colors.white)
                          : null,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      InkWell(
                        onTap: () => _openUserProfile(post),
                        borderRadius: BorderRadius.circular(8),
                        child: Text(
                          post.username ?? 'Pet User',

                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _timeAgo(post.createdAt),

                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),

                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 42),
              ],
            ),
          ),

          // ───────────────── MEDIA ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),

            child: GestureDetector(
              onDoubleTap: () async {
                await _postService.toggleLike(post.id);

                await Future.delayed(const Duration(milliseconds: 700));

                if (!mounted) return;

                _animatingPostId = post.id;

                Future.delayed(const Duration(milliseconds: 700), () {
                  if (!mounted) return;

                  _animatingPostId = null;
                });
              },

              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),

                child: Stack(
                  alignment: Alignment.bottomCenter,

                  children: [
                    Hero(
                      tag: post.id,

                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: _PostMediaCarousel(
                          post: post,
                          onOpenViewer: (mediaIndex) {
                            setState(() {
                              _viewerPost = post;
                              _viewerMediaIndex = mediaIndex;
                            });
                          },
                        ),
                      ),
                    ),

                    // gradient overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,

                              colors: [
                                Colors.transparent,

                                Colors.black.withValues(alpha: 0.15),

                                Colors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    AnimatedOpacity(
                      opacity: _animatingPostId == post.id ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.5, end: 1.2),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 120,
                        ),
                      ),
                    ),

                    // floating actions
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,

                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                if (post.caption.isNotEmpty)
                                  Text(
                                    post.caption,

                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(
                                      color: Colors.white,

                                      fontSize: 17,

                                      fontWeight: FontWeight.w600,

                                      height: 1.3,
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    _buildActionButton(
                                      icon: LucideIcons.heart,
                                      count: post.likeCount.toString(),
                                      onTap: () async {
                                        await _postService.toggleLike(post.id);
                                      },
                                    ),

                                    const SizedBox(width: 18),

                                    _buildActionButton(
                                      icon: LucideIcons.messageCircle,
                                      count: post.commentCount.toString(),
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) =>
                                              CommentsBottomSheet(post: post),
                                        );
                                      },
                                    ),

                                    const SizedBox(width: 18),

                                    _buildActionButton(
                                      icon: LucideIcons.send,
                                      count: post.shareCount.toString(),
                                      onTap: () {
                                        sharePost(post);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 18),

                          Column(
                            children: [
                              Material(
                                color: Colors.transparent,

                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),

                                  onTap: () async {
                                    debugPrint('🔥 SAVE POST TAP');

                                    try {
                                      await _saveService.toggleSave(post.id);

                                      if (!mounted) return;

                                      debugPrint('✅ SAVE TOGGLED');
                                    } catch (e) {
                                      debugPrint('❌ SAVE ERROR: $e');
                                    }
                                  },

                                  child: Ink(
                                    height: 56,
                                    width: 56,

                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),

                                      borderRadius: BorderRadius.circular(18),

                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                      ),
                                    ),

                                    child: const Icon(
                                      LucideIcons.bookmark,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sharePost(SocialPost post) async {
    try {
      final box = context.findRenderObject() as RenderBox?;

      await Share.share('''
🐾 Seen on PetSupo

${post.caption}

https://petsupo.com/post/${post.id}
''', sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);

      await _postService.incrementShareCount(post.id);
    } catch (e) {
      debugPrint('SHARE ERROR: $e');
    }
  }

  void _openUserProfile(SocialPost post) {
    if (post.userId.trim().isEmpty) return;

    final appState = context.read<AppState>();
    appState.openPetploreProfile(post.userId);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),

          const SizedBox(width: 7),

          Text(
            count,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(Object value) {
    final date = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : DateTime.now();

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }

    return '${diff.inDays}d';
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final SocialPost post;
  final ValueChanged<int> onOpenViewer;

  const _PostMediaCarousel({required this.post, required this.onOpenViewer});

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  late final PageController _controller;
  int _index = 0;

  List<SocialPostMedia> get _media {
    if (widget.post.media.isNotEmpty) {
      return widget.post.media;
    }

    return widget.post.mediaUrls
        .map(
          (url) => SocialPostMedia(
            url: url,
            type: widget.post.mediaType == 'video' ? 'video' : 'image',
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;

    if (media.isEmpty) {
      return Container(
        color: Colors.white10,
        child: const Center(
          child: Icon(LucideIcons.imageOff, color: Colors.white38, size: 42),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: media.length,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            final item = media[index];

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onOpenViewer(index),
              child: _FeedMediaItem(media: item),
            );
          },
        ),
        if (media.length > 1)
          Positioned(
            top: 14,
            right: 14,
            child: _CarouselCounter(index: _index + 1, count: media.length),
          ),
        if (media.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _CarouselDots(count: media.length, index: _index),
          ),
      ],
    );
  }
}

class _FeedMediaItem extends StatelessWidget {
  final SocialPostMedia media;

  const _FeedMediaItem({required this.media});

  @override
  Widget build(BuildContext context) {
    final previewUrl = media.previewUrl;

    if (previewUrl.isEmpty) {
      return Container(
        color: Colors.white10,
        child: const Icon(
          LucideIcons.imageOff,
          color: Colors.white38,
          size: 42,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: previewUrl,
          fit: BoxFit.cover,
          memCacheWidth: 900,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) {
            return Container(
              color: Colors.white10,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            );
          },
          errorWidget: (context, url, error) {
            return Container(
              color: Colors.white10,
              child: const Center(
                child: Icon(
                  LucideIcons.imageOff,
                  color: Colors.white38,
                  size: 42,
                ),
              ),
            );
          },
        ),
        if (media.isVideo) ...[
          Container(color: Colors.black.withValues(alpha: 0.16)),
          const Center(
            child: Icon(LucideIcons.playCircle, color: Colors.white, size: 62),
          ),
        ],
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  final int count;
  final int index;

  const _CarouselDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 7 : 5,
          height: active ? 7 : 5,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _CarouselCounter extends StatelessWidget {
  final int index;
  final int count;

  const _CarouselCounter({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$index / $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SocialFeedSinglePost extends StatelessWidget {
  final SocialPost post;

  const SocialFeedSinglePost({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final media = post.media.isNotEmpty
        ? post.media.first
        : post.mediaUrls.isNotEmpty
        ? SocialPostMedia(
            url: post.mediaUrls.first,
            type: post.mediaType == 'video' ? 'video' : 'image',
          )
        : null;

    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 1,

          child: Hero(
            tag: post.id,

            child: media == null
                ? Container(
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: Colors.white38,
                        size: 42,
                      ),
                    ),
                  )
                : _FeedMediaItem(media: media),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                post.username ?? 'Pet User',

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                post.caption,

                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
