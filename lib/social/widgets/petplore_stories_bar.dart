import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/pet_story.dart';
import '../pages/pet_story_viewer_page.dart';
import '../services/pet_story_service.dart';

class PetploreStoriesBar extends StatefulWidget {
  const PetploreStoriesBar({super.key});

  @override
  State<PetploreStoriesBar> createState() => _PetploreStoriesBarState();
}

class _PetploreStoriesBarState extends State<PetploreStoriesBar> {
  final PetStoryService _storyService = PetStoryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _addStory() async {
    if (_isUploading) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await _storyService.createStory(
        file: File(image.path),
        mediaType: 'image',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story uploaded')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Story upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.03), Colors.transparent],
        ),
      ),
      child: SizedBox(
        height: 122,
        child: StreamBuilder<List<PetStory>>(
          stream: _storyService.streamActiveStories(),
          builder: (context, snapshot) {
            final stories = snapshot.data ?? [];
            final grouped = _groupStoriesByUser(stories);
            final users = grouped.keys.toList();
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return StreamBuilder<Set<String>>(
              stream: _streamViewedStoryIds(),
              builder: (context, viewedSnapshot) {
                final viewedStoryIds = viewedSnapshot.data ?? <String>{};

                if (isLoading && stories.isEmpty) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildAddStoryButton();
                      return _buildLoadingStory();
                    },
                  );
                }

                if (users.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildAddStoryButton(),
                      const SizedBox(width: 14),
                      _buildEmptyStoryHint(),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: users.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildAddStoryButton();

                    final userId = users[index - 1];
                    final userStories = grouped[userId]!;
                    return _buildStoryCircle(userStories, viewedStoryIds);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Map<String, List<PetStory>> _groupStoriesByUser(List<PetStory> stories) {
    final grouped = <String, List<PetStory>>{};

    for (final story in stories) {
      grouped.putIfAbsent(story.userId, () => []).add(story);
    }

    return grouped;
  }

  Stream<Set<String>> _streamViewedStoryIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});

    return _firestore
        .collectionGroup('views')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final storyIds = <String>{};

          for (final doc in snapshot.docs) {
            final storyId = doc.reference.parent.parent?.id;
            if (storyId != null && storyId.isNotEmpty) {
              storyIds.add(storyId);
            }
          }

          return storyIds;
        });
  }

  Widget _buildAddStoryButton() {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          GestureDetector(
            onTap: _addStory,
            child: Container(
              height: 68,
              width: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFF4D8D)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D8D).withValues(alpha: 0.22),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isUploading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Add Story',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCircle(List<PetStory> stories, Set<String> viewedStoryIds) {
    final sortedStories = [...stories]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final story = sortedStories.first;
    final allViewed = sortedStories.every((story) {
      return viewedStoryIds.contains(story.id);
    });
    final firstUnseenIndex = sortedStories.indexWhere((story) {
      return !viewedStoryIds.contains(story.id);
    });
    final initialIndex = firstUnseenIndex == -1 ? 0 : firstUnseenIndex;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PetStoryViewerPage(
              stories: sortedStories,
              initialIndex: initialIndex,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              height: 68,
              width: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: allViewed
                    ? LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.14),
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFF4D8D), Color(0xFFFF9A62)],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (allViewed ? Colors.white : const Color(0xFFFF4D8D))
                        .withValues(alpha: allViewed ? 0.08 : 0.28),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    story.userAvatarUrl != null &&
                        story.userAvatarUrl!.trim().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: story.userAvatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              story.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStory() {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 46,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStoryHint() {
    return SizedBox(
      width: 164,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Share a pet moment that lasts 24h',
          maxLines: 2,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Icon(
        LucideIcons.dog,
        color: Colors.white.withValues(alpha: 0.86),
        size: 28,
      ),
    );
  }
}
