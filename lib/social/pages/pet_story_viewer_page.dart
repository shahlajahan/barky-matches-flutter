import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../models/pet_story.dart';
import '../services/pet_story_service.dart';

class PetStoryViewerPage extends StatefulWidget {
  final List<PetStory> stories;
  final int initialIndex;

  const PetStoryViewerPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<PetStoryViewerPage> createState() => _PetStoryViewerPageState();
}

class _PetStoryViewerPageState extends State<PetStoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _imageStoryDuration = Duration(seconds: 5);

  final PetStoryService _storyService = PetStoryService();
  final Set<String> _markedStoryIds = {};
  final TextEditingController _replyController = TextEditingController();

  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isLikeToggling = false;
  bool _isReplySending = false;
  bool _isSharing = false;

  PetStory get _story => widget.stories[_currentIndex];

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.stories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _imageStoryDuration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleStoryVisible();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _handleStoryVisible() {
    if (!mounted || widget.stories.isEmpty) return;

    final story = _story;
    debugPrint('👁️ STORY OPENED: ${story.id}');
    debugPrint('🖼 STORY IMAGE URL: ${story.mediaUrl}');
    _markCurrentStoryViewed();
    _startTimerForCurrentStory();
  }

  Future<void> _markCurrentStoryViewed() async {
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) {
      return;
    }

    final story = _story;
    if (_markedStoryIds.contains(story.id)) return;
    _markedStoryIds.add(story.id);

    try {
      await _storyService.markViewed(story.id);
    } catch (e) {
      debugPrint('❌ Petplore story mark viewed failed: $e');
    }
  }

  void _startTimerForCurrentStory() {
    _timer?.cancel();
    _progressController.stop();
    _progressController.reset();

    if (widget.stories.isEmpty || _story.mediaType == 'video') return;

    _progressController.forward(from: 0);
    _timer = Timer(_imageStoryDuration, _next);
  }

  void _pauseStory() {
    _timer?.cancel();
    _progressController.stop();
    debugPrint('⏸️ STORY PAUSED');
  }

  void _resumeStory() {
    if (widget.stories.isEmpty || _story.mediaType == 'video') return;

    final remainingMs =
        (_imageStoryDuration.inMilliseconds * (1 - _progressController.value))
            .round();
    final remaining = Duration(milliseconds: remainingMs.clamp(250, 5000));

    _timer?.cancel();
    _progressController.forward();
    _timer = Timer(remaining, _next);
    debugPrint('▶️ STORY RESUMED');
  }

  void _next() {
    if (!mounted || widget.stories.isEmpty) return;

    debugPrint('➡️ STORY NEXT');

    if (_currentIndex >= widget.stories.length - 1) {
      Navigator.pop(context);
      return;
    }

    _goToIndex(_currentIndex + 1);
  }

  void _previous() {
    if (!mounted || widget.stories.isEmpty || _currentIndex <= 0) return;

    debugPrint('⬅️ STORY PREVIOUS');
    _goToIndex(_currentIndex - 1);
  }

  void _goToIndex(int index) {
    final safeIndex = index.clamp(0, widget.stories.length - 1);

    setState(() {
      _currentIndex = safeIndex;
    });
    _pageController.animateToPage(
      safeIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _handleStoryVisible();
  }

  void _handlePageChanged(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
    _handleStoryVisible();
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 280) {
            Navigator.pop(context);
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        child: PageView.builder(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: _handlePageChanged,
          itemCount: widget.stories.length,
          itemBuilder: (context, index) {
            final story = widget.stories[index];
            debugPrint('✅ STORY RENDERED: ${story.id}');

            return _buildStoryPage(story);
          },
        ),
      ),
    );
  }

  Widget _buildStoryPage(PetStory story) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildStoryMedia(story),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.70),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _previous,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(child: _buildTopOverlay(story)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: IgnorePointer(
              ignoring: false,
              child: _buildBottomOverlay(story),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryMedia(PetStory story) {
    if (story.mediaType == 'video') {
      return _buildVideoPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) {
        return const Center(child: CircularProgressIndicator());
      },
      errorWidget: (context, url, error) {
        debugPrint('❌ STORY IMAGE FAILED');

        return const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.white,
            size: 40,
          ),
        );
      },
    );
  }

  Widget _buildTopOverlay(PetStory story) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressBars(),
          const SizedBox(height: 12),
          _buildHeader(story),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay(PetStory story) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width - 16 - 16 - 12 - 48 - 10 - 48,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _replyController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendReply(),
              decoration: const InputDecoration(
                hintText: 'Reply...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildLikeButton(story),
        const SizedBox(width: 10),
        _storyActionButton(icon: Icons.send_rounded, onTap: _shareStory),
      ],
    );
  }

  Widget _buildLikeButton(PetStory story) {
    return StreamBuilder<bool>(
      stream: _storyService.likeStream(story.id),
      builder: (context, snapshot) {
        final liked = snapshot.data ?? false;

        return _storyActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? const Color(0xFFFF4D8D) : Colors.white,
          onTap: _toggleLike,
        );
      },
    );
  }

  Widget _storyActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_isLikeToggling) return;

    final story = widget.stories[_currentIndex];
    _isLikeToggling = true;

    try {
      await _storyService.toggleLike(story.id);
      debugPrint('❤️ STORY LIKE TOGGLE REAL: ${story.id}');
    } catch (e) {
      debugPrint('❌ STORY LIKE FAILED: $e');
    } finally {
      _isLikeToggling = false;
    }
  }

  Future<void> _sendReply() async {
    if (_isReplySending) return;

    final story = widget.stories[_currentIndex];
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _isReplySending = true;

    try {
      await _storyService.sendReply(story: story, text: text);
      _replyController.clear();
      debugPrint('💬 STORY REPLY SENT: ${story.id}');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent')));
    } catch (e) {
      debugPrint('❌ STORY REPLY FAILED: $e');
    } finally {
      _isReplySending = false;
    }
  }

  Future<void> _shareStory() async {
    if (_isSharing) return;

    final story = widget.stories[_currentIndex];
    _isSharing = true;

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;

      await Share.share('''
🐾 Seen on PetSupo

https://petsupo.com/story/${story.id}
''', sharePositionOrigin: origin);

      await _storyService.incrementShareCount(story.id);
      debugPrint('📤 STORY SHARE REAL: ${story.id}');
    } catch (e) {
      debugPrint('❌ STORY SHARE FAILED: $e');
    } finally {
      _isSharing = false;
    }
  }

  Widget _buildProgressBars() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final gapCount = widget.stories.length - 1;
            final totalGap = gapCount * 5;
            final segmentWidth =
                (constraints.maxWidth - totalGap) / widget.stories.length;

            return Row(
              children: List.generate(widget.stories.length, (index) {
                final progress = index < _currentIndex
                    ? 1.0
                    : index == _currentIndex
                    ? _progressController.value
                    : 0.0;

                return Container(
                  width: segmentWidth,
                  height: 3,
                  margin: EdgeInsets.only(
                    right: index == widget.stories.length - 1 ? 0 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      curve: Curves.linear,
                      width: segmentWidth * progress.clamp(0.0, 1.0),
                      color: Colors.white,
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(PetStory story) {
    final hasAvatar =
        story.userAvatarUrl != null && story.userAvatarUrl!.trim().isNotEmpty;
    final contentWidth = MediaQuery.sizeOf(context).width - 24;
    final nameWidth = contentWidth - 20 - 36 - 10 - 8 - 34 - 48;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white12,
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(story.userAvatarUrl!)
                : null,
            child: hasAvatar
                ? null
                : const Icon(LucideIcons.dog, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: nameWidth.clamp(80, contentWidth),
            child: Text(
              story.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              _relativeTime(story.createdAt),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white.withValues(alpha: 0.86),
            size: 68,
          ),
          const SizedBox(height: 10),
          Text(
            'Video stories are coming soon',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
