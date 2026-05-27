import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'create_social_post_page.dart';
import 'saved_posts_page.dart';
import 'social_feed_page.dart';
import '../widgets/user_posts_grid.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/follow_service.dart';
import '../overlay/petplore_search_overlay.dart';

class PetplorePage extends StatefulWidget {
  const PetplorePage({super.key});

  @override
  State<PetplorePage> createState() => _PetplorePageState();
}

class _PetplorePageState extends State<PetplorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FollowService _followService = FollowService();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Container(
      color: Colors.black,

      child: Stack(
        children: [
          // ───────────────── MAIN CONTENT ─────────────────
          Column(
            children: [
              // ───────────────── HEADER ─────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // PET ICON
                    Container(
                      height: 50,
                      width: 50,

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),

                        borderRadius: BorderRadius.circular(18),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),

                      child: const Icon(
                        LucideIcons.dog,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 18),

                    // TITLE + STATS
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          // TITLE
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                colors: [Color(0xFFFF4D8D), Color(0xFFFFA26B)],
                              ).createShader(bounds);
                            },

                            child: const Text(
                              'Petplore',

                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.6,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // SUBTITLE
                          Text(
                            'Explore pet moments',

                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),

                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // FOLLOW STATS
                          if (currentUserId != null) ...[
                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,

                              children: [
                                // FOLLOWERS
                                StreamBuilder<int>(
                                  stream: _followService.followersCountStream(
                                    currentUserId,
                                  ),

                                  builder: (context, snapshot) {
                                    final followers = snapshot.data ?? 0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),

                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),

                                        borderRadius: BorderRadius.circular(12),

                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                        ),
                                      ),

                                      child: Text(
                                        '$followers Followers',

                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),

                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // FOLLOWING
                                StreamBuilder<int>(
                                  stream: _followService.followingCountStream(
                                    currentUserId,
                                  ),

                                  builder: (context, snapshot) {
                                    final following = snapshot.data ?? 0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),

                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),

                                        borderRadius: BorderRadius.circular(12),

                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                        ),
                                      ),

                                      child: Text(
                                        '$following Following',

                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),

                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // SEARCH
                    Material(
                      color: Colors.transparent,

                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),

                        onTap: () {
                          showGeneralDialog(
                            context: context,

                            barrierDismissible: true,

                            barrierLabel: 'PetploreSearch',

                            barrierColor: Colors.black.withOpacity(0.45),

                            transitionDuration: const Duration(
                              milliseconds: 260,
                            ),

                            pageBuilder: (_, __, ___) {
                              return const PetploreSearchOverlay();
                            },

                            transitionBuilder: (context, animation, _, child) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.04),
                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                          );
                        },

                        child: Container(
                          height: 50,
                          width: 50,

                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),

                            borderRadius: BorderRadius.circular(18),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),

                          child: const Icon(
                            LucideIcons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ───────────────── TABS ─────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),

                child: Container(
                  height: 66,

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),

                    borderRadius: BorderRadius.circular(24),

                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),

                  child: TabBar(
                    controller: _tabController,

                    dividerColor: Colors.transparent,

                    indicatorPadding: const EdgeInsets.all(7),

                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),

                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,

                        colors: [Color(0xFFFF4D8D), Color(0xFFFF8A65)],
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFF4D8D,
                          ).withValues(alpha: 0.35),

                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    labelColor: Colors.white,

                    unselectedLabelColor: Colors.white.withValues(alpha: 0.55),

                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),

                    tabs: const [
                      Tab(
                        icon: Icon(LucideIcons.compass, size: 20),

                        text: 'Feed',
                      ),

                      Tab(
                        icon: Icon(LucideIcons.bookmark, size: 20),

                        text: 'Saved',
                      ),

                      Tab(
                        icon: Icon(LucideIcons.layoutGrid, size: 20),

                        text: 'My Posts',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ───────────────── CONTENT ─────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,

                  children: const [
                    SocialFeedPage(),

                    SavedPostsPage(),

                    _MyPostsTab(),
                  ],
                ),
              ),
            ],
          ),

          // ───────────────── FLOATING CREATE BUTTON ─────────────────
          Positioned(
            right: 22,
            bottom: 26,

            child: Container(
              height: 64,
              width: 64,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,

                  colors: [Color(0xFFFF4D8D), Color(0xFFFF8A65)],
                ),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D8D).withValues(alpha: 0.28),

                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Material(
                color: Colors.transparent,

                child: InkWell(
                  borderRadius: BorderRadius.circular(100),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateSocialPostPage(),
                      ),
                    );
                  },

                  child: const Center(
                    child: Icon(
                      LucideIcons.plus,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPostsTab extends StatelessWidget {
  const _MyPostsTab();

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(
        child: Text(
          'Login required',

          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,

      child: UserPostsGrid(userId: currentUserId),
    );
  }
}
