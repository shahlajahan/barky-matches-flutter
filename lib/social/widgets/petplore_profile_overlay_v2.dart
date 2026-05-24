import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/social/models/social_post.dart';
import 'package:barky_matches_fixed/social/services/follow_service.dart';
import 'package:barky_matches_fixed/social/widgets/social_post_media_viewer_overlay.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetploreProfileOverlayV2 extends StatefulWidget {
  final String userId;
  final List<Dog> dogs;

  const PetploreProfileOverlayV2({
    super.key,
    required this.userId,
    required this.dogs,
  });

  @override
  State<PetploreProfileOverlayV2> createState() =>
      _PetploreProfileOverlayV2State();
}

class _PetploreProfileOverlayV2State extends State<PetploreProfileOverlayV2> {
  final FollowService _followService = FollowService();
  final ScrollController _scrollController = ScrollController();
  final List<SocialPost> _posts = [];

  DocumentSnapshot<Map<String, dynamic>>? _lastPostDoc;
  bool _isLoadingPosts = false;
  bool _hasMorePosts = true;
  int? _viewerIndex;
  int _viewerMediaIndex = 0;
  _SocialGraphPanelConfig? _graphPanel;

  @override
  void initState() {
    super.initState();
    _loadPosts(reset: true);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant PetploreProfileOverlayV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _viewerIndex = null;
      _loadPosts(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingPosts || !_hasMorePosts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 420) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (_isLoadingPosts) return;

    setState(() {
      _isLoadingPosts = true;
      if (reset) {
        _posts.clear();
        _lastPostDoc = null;
        _hasMorePosts = true;
      }
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('social_posts')
          .where('userId', isEqualTo: widget.userId)
          .where('visibility', isEqualTo: 'public')
          .where('moderationStatus', isEqualTo: 'active')
          .where('isHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(18);

      if (_lastPostDoc != null) {
        query = query.startAfterDocument(_lastPostDoc!);
      }

      final snapshot = await query.get();
      final nextPosts = snapshot.docs
          .map((doc) => SocialPost.fromFirestore(doc))
          .toList();

      if (!mounted) return;

      setState(() {
        _posts.addAll(nextPosts);
        _lastPostDoc = snapshot.docs.isEmpty
            ? _lastPostDoc
            : snapshot.docs.last;
        _hasMorePosts = snapshot.docs.length == 18;
      });
    } catch (e) {
      debugPrint('Petplore profile posts load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  void _openViewer(int index, int mediaIndex) {
    setState(() {
      _viewerIndex = index;
      _viewerMediaIndex = mediaIndex;
    });
  }

  void _closeViewer() {
    setState(() {
      _viewerIndex = null;
      _viewerMediaIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_viewerIndex != null) {
            _closeViewer();
          } else {
            appState.closePetploreProfile();
          }
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: appState.closePetploreProfile,
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                    ),
                    margin: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final user = _PetploreProfileUser.fromMap(
                              widget.userId,
                              snapshot.data?.data() ?? {},
                            );

                            return CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                SliverToBoxAdapter(
                                  child: _ProfileHeader(
                                    user: user,
                                    postCount: user.postsCount ?? _posts.length,
                                    followersStream: _followService
                                        .followersCountStream(widget.userId),
                                    followingStream: _followService
                                        .followingCountStream(widget.userId),
                                    onClose: appState.closePetploreProfile,
                                    onFollowersTap: () {
                                      _openSocialGraphPanel(
                                        context,
                                        title: 'Followers',
                                        collection: 'followers',
                                        subcollection: 'userFollowers',
                                      );
                                    },
                                    onFollowingTap: () {
                                      _openSocialGraphPanel(
                                        context,
                                        title: 'Following',
                                        collection: 'following',
                                        subcollection: 'userFollowing',
                                      );
                                    },
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: _PostsSectionHeader(
                                    isLoading:
                                        _isLoadingPosts && _posts.isEmpty,
                                  ),
                                ),
                                _PostsGrid(posts: _posts, onTap: _openViewer),
                                SliverToBoxAdapter(
                                  child: _DogsSection(
                                    dogs: widget.dogs
                                        .where(
                                          (dog) => dog.ownerId == widget.userId,
                                        )
                                        .toList(),
                                    allDogs: widget.dogs,
                                  ),
                                ),
                                if (_isLoadingPosts)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 28),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                ),
              ),
            ),
          ),
          if (_viewerIndex != null)
            Positioned.fill(
              child: SocialPostMediaViewerOverlay(
                posts: _posts,
                initialPostIndex: _viewerIndex!,
                initialMediaIndex: _viewerMediaIndex,
                onClose: _closeViewer,
              ),
            ),
          if (_graphPanel != null)
            Positioned.fill(
              child: _SocialGraphPanel(
                title: _graphPanel!.title,
                userId: widget.userId,
                collection: _graphPanel!.collection,
                subcollection: _graphPanel!.subcollection,
                onClose: () => setState(() => _graphPanel = null),
              ),
            ),
        ],
      ),
    );
  }

  void _openSocialGraphPanel(
    BuildContext context, {
    required String title,
    required String collection,
    required String subcollection,
  }) {
    setState(() {
      _graphPanel = _SocialGraphPanelConfig(
        title: title,
        collection: collection,
        subcollection: subcollection,
      );
    });
  }
}

class _SocialGraphPanelConfig {
  final String title;
  final String collection;
  final String subcollection;

  const _SocialGraphPanelConfig({
    required this.title,
    required this.collection,
    required this.subcollection,
  });
}

class _ProfileHeader extends StatelessWidget {
  final _PetploreProfileUser user;
  final int postCount;
  final Stream<int> followersStream;
  final Stream<int> followingStream;
  final VoidCallback onClose;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _ProfileHeader({
    required this.user,
    required this.postCount,
    required this.followersStream,
    required this.followingStream,
    required this.onClose,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == user.id;
    final joined = user.joinedAt == null
        ? null
        : 'Joined ${_monthName(user.joinedAt!.month)} ${user.joinedAt!.year}';
    final location = user.locationLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
              const Spacer(),
              if (!isOwnProfile) _PetploreFollowButton(userId: user.id),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white12,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? const Icon(
                        LucideIcons.user,
                        color: Colors.white70,
                        size: 34,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@${user.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.h2(
                              color: Colors.white,
                              weight: FontWeight.w900,
                              size: 20,
                            ),
                          ),
                        ),
                        if (user.isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.badgeCheck,
                            color: Color(0xFFFFD166),
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (user.displayName.isNotEmpty)
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          color: Colors.white.withValues(alpha: 0.86),
                          weight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (location.isNotEmpty)
                          _ProfileMetaChip(text: location),
                        if (joined != null) _ProfileMetaChip(text: joined),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatsRow(
            postCount: postCount,
            followersStream: followersStream,
            followingStream: followingStream,
            onFollowersTap: onFollowersTap,
            onFollowingTap: onFollowingTap,
          ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              user.bio,
              style: AppTheme.body(
                color: Colors.white.withValues(alpha: 0.78),
                size: 13,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _ProfileMetaChip extends StatelessWidget {
  final String text;

  const _ProfileMetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.caption(
        color: Colors.white.withValues(alpha: 0.54),
        weight: FontWeight.w700,
        size: 12,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int postCount;
  final Stream<int> followersStream;
  final Stream<int> followingStream;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _StatsRow({
    required this.postCount,
    required this.followersStream,
    required this.followingStream,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(count: postCount, label: 'posts'),
        StreamBuilder<int>(
          stream: followersStream,
          builder: (context, snapshot) {
            return _StatItem(
              count: snapshot.data ?? 0,
              label: 'followers',
              onTap: onFollowersTap,
            );
          },
        ),
        StreamBuilder<int>(
          stream: followingStream,
          builder: (context, snapshot) {
            return _StatItem(
              count: snapshot.data ?? 0,
              label: 'following',
              onTap: onFollowingTap,
            );
          },
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                _compactCount(count),
                style: AppTheme.h2(
                  color: Colors.white,
                  weight: FontWeight.w900,
                  size: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTheme.caption(
                  color: Colors.white.withValues(alpha: 0.56),
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }
}

class _PetploreFollowButton extends StatefulWidget {
  final String userId;

  const _PetploreFollowButton({required this.userId});

  @override
  State<_PetploreFollowButton> createState() => _PetploreFollowButtonState();
}

class _PetploreFollowButtonState extends State<_PetploreFollowButton> {
  final FollowService _followService = FollowService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _followService.isFollowing(widget.userId),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      if (following) {
                        await _followService.unfollowUser(
                          targetUserId: widget.userId,
                        );
                      } else {
                        await _followService.followUser(
                          targetUserId: widget.userId,
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: following
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: following
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: AppTheme.button(
                  color: following ? Colors.white : Colors.black,
                ).copyWith(fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PostsSectionHeader extends StatelessWidget {
  final bool isLoading;

  const _PostsSectionHeader({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        children: [
          const Icon(LucideIcons.grid, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Posts', style: AppTheme.h3(color: Colors.white)),
          if (isLoading) ...[
            const Spacer(),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  final List<SocialPost> posts;
  final void Function(int postIndex, int mediaIndex) onTap;

  const _PostsGrid({required this.posts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Text(
            'No posts yet',
            style: AppTheme.body(
              color: Colors.white.withValues(alpha: 0.52),
              weight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        itemCount: posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          final post = posts[index];
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
          final cover = media.isNotEmpty ? media.first : null;
          final url = cover?.previewUrl ?? '';

          return InkWell(
            onTap: () => onTap(index, 0),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url.isEmpty)
                    Container(
                      color: Colors.white.withValues(alpha: 0.08),
                      child: const Icon(
                        LucideIcons.imageOff,
                        color: Colors.white38,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      memCacheWidth: 360,
                      placeholder: (context, url) => Container(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.white.withValues(alpha: 0.08),
                        child: const Icon(
                          LucideIcons.imageOff,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  if (media.length > 1)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        LucideIcons.copy,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  if (cover?.isVideo == true)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  if (post.likeCount > 0)
                    Positioned(
                      left: 7,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.heart,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            post.likeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DogsSection extends StatelessWidget {
  final List<Dog> dogs;
  final List<Dog> allDogs;

  const _DogsSection({required this.dogs, required this.allDogs});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.dog, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Dogs', style: AppTheme.h3(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          if (dogs.isEmpty)
            Text(
              'No dogs found for this user',
              style: AppTheme.body(color: Colors.white.withValues(alpha: 0.52)),
            )
          else
            ...dogs.map(
              (dog) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DogCard(
                  dog: dog,
                  mode: DogCardMode.playdate,
                  disableTap: true,
                  allDogs: allDogs,
                  currentUserId: appState.currentUserId ?? '',
                  favoriteDogs: appState.favoriteDogs,
                  onToggleFavorite: appState.toggleFavorite,
                  likers: appState.dogLikes[dog.id] ?? [],
                  enableEdit: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialGraphPanel extends StatelessWidget {
  final String title;
  final String userId;
  final String collection;
  final String subcollection;
  final VoidCallback onClose;

  const _SocialGraphPanel({
    required this.title,
    required this.userId,
    required this.collection,
    required this.subcollection,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: Colors.black54),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.72,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Text(title, style: AppTheme.h2(color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(collection)
                        .doc(userId)
                        .collection(subcollection)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final ids = (snapshot.data?.docs ?? [])
                          .map((doc) => doc.id)
                          .toList();

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      if (ids.isEmpty) {
                        return Center(
                          child: Text(
                            'No ${title.toLowerCase()} yet',
                            style: AppTheme.body(
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
                          ),
                        );
                      }

                      return FutureBuilder<Map<String, _PetploreProfileUser>>(
                        future: _loadUsers(ids),
                        builder: (context, usersSnapshot) {
                          final users = usersSnapshot.data ?? {};
                          if (usersSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                            itemCount: ids.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final profile =
                                  users[ids[index]] ??
                                  _PetploreProfileUser.empty(ids[index]);
                              return _SocialGraphUserTile(
                                user: profile,
                                onTap: onClose,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, _PetploreProfileUser>> _loadUsers(List<String> ids) async {
    final result = <String, _PetploreProfileUser>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        result[doc.id] = _PetploreProfileUser.fromMap(doc.id, doc.data());
      }
    }
    return result;
  }
}

class _SocialGraphUserTile extends StatelessWidget {
  final _PetploreProfileUser user;
  final VoidCallback onTap;

  const _SocialGraphUserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        onTap();
        context.read<AppState>().openPetploreProfile(user.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white12,
              backgroundImage: user.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoUrl)
                  : null,
              child: user.photoUrl.isEmpty
                  ? const Icon(LucideIcons.user, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ),
            ),
            if (currentUserId != user.id)
              _PetploreFollowButton(userId: user.id),
          ],
        ),
      ),
    );
  }
}

class _PetploreProfileUser {
  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String city;
  final String district;
  final String photoUrl;
  final bool isPremium;
  final int? postsCount;
  final DateTime? joinedAt;

  const _PetploreProfileUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.city,
    required this.district,
    required this.photoUrl,
    required this.isPremium,
    required this.postsCount,
    required this.joinedAt,
  });

  factory _PetploreProfileUser.empty(String id) {
    return _PetploreProfileUser(
      id: id,
      username: 'petuser',
      displayName: 'Pet User',
      bio: '',
      city: '',
      district: '',
      photoUrl: '',
      isPremium: false,
      postsCount: null,
      joinedAt: null,
    );
  }

  factory _PetploreProfileUser.fromMap(String id, Map<String, dynamic> data) {
    debugPrint('PROFILE RAW DATA = $data');
    return _PetploreProfileUser(
      id: id,
      username: _firstNonEmpty(
        data['username'],
        data['name'],
        data['displayName'],
        'petuser',
      ),
      displayName: _firstNonEmpty(
        data['displayName'],
        data['name'],
        data['username'],
        'Pet User',
      ),
      bio: _firstNonEmpty(data['bio'], null, null, ''),
      city: _firstNonEmpty(data['city'], null, null, ''),
      district: _firstNonEmpty(data['district'], null, null, ''),
      photoUrl: _firstNonEmpty(
        data['profilePhoto'],
        data['photoUrl'],
        data['profileImageUrl'],
        '',
      ),
      isPremium: data['isPremium'] == true || data['premium'] == true,
      postsCount: _readInt(data['postsCount']),
      joinedAt: _readDate(data['joinedAt'] ?? data['createdAt']),
    );
  }

  String get locationLabel {
    if (city.isNotEmpty && district.isNotEmpty) {
      return '$district, $city';
    }

    if (city.isNotEmpty) return city;
    return '';
  }

  static String _firstNonEmpty(
    Object? first,
    Object? second,
    Object? third,
    String fallback,
  ) {
    for (final value in [first, second, third]) {
      if (value == null) continue;

      // STRING
      if (value is String) {
        final text = value.trim();

        if (text.isNotEmpty) {
          return text;
        }
      }

      // MAP SUPPORT
      if (value is Map) {
        final possible = [
          value['name'],
          value['title'],
          value['value'],
          value['city'],
        ];

        for (final item in possible) {
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
        }
      }
    }

    return fallback;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
