import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/social/services/follow_service.dart';

class FollowersListPage extends StatelessWidget {
  final String userId;

  const FollowersListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FollowUsersListPage(
      title: 'Followers',
      userId: userId,
      collection: 'followers',
      subcollection: 'userFollowers',
    );
  }
}

class FollowUserListTile extends StatelessWidget {
  final FollowUserProfile profile;
  final VoidCallback onTap;

  const FollowUserListTile({
    super.key,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnUser = currentUserId == profile.userId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white12,
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty
                    ? const Icon(LucideIcons.user, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (profile.isPremium) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.badgeCheck,
                        color: Color(0xFFFFD166),
                        size: 17,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isOwnUser) FollowUserButton(targetUserId: profile.userId),
            ],
          ),
        ),
      ),
    );
  }
}

class FollowUserButton extends StatelessWidget {
  final String targetUserId;

  const FollowUserButton({super.key, required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final followService = FollowService();

    return StreamBuilder<bool>(
      stream: followService.isFollowing(targetUserId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            if (isFollowing) {
              await followService.unfollowUser(targetUserId: targetUserId);
            } else {
              await followService.followUser(targetUserId: targetUserId);
            }
          },
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFollowing
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFollowing
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                color: isFollowing ? Colors.white : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FollowUsersListPage extends StatelessWidget {
  final String title;
  final String userId;
  final String collection;
  final String subcollection;

  const FollowUsersListPage({
    super.key,
    required this.title,
    required this.userId,
    required this.collection,
    required this.subcollection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final ids = docs.map((doc) => doc.id).toList();

                  if (ids.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${title.toLowerCase()} yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<Map<String, FollowUserProfile>>(
                    future: _loadUsers(ids),
                    builder: (context, usersSnapshot) {
                      final users = usersSnapshot.data ?? {};

                      if (usersSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: ids.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final profile =
                              users[id] ??
                              FollowUserProfile(
                                userId: id,
                                username: 'Pet User',
                                avatarUrl: '',
                                isPremium: false,
                              );

                          return FollowUserListTile(
                            profile: profile,
                            onTap: () {
                              final appState = context.read<AppState>();
                              Navigator.pop(context);
                              appState.setPlaymateProfile(
                                profile.userId,
                                appState.allDogs,
                              );
                            },
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
    );
  }

  Future<Map<String, FollowUserProfile>> _loadUsers(List<String> ids) async {
    final result = <String, FollowUserProfile>{};
    final firestore = FirebaseFirestore.instance;

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snapshot = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        result[doc.id] = FollowUserProfile.fromUserDoc(doc.id, data);
      }
    }

    return result;
  }
}

class FollowUserProfile {
  final String userId;
  final String username;
  final String avatarUrl;
  final bool isPremium;

  const FollowUserProfile({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isPremium,
  });

  factory FollowUserProfile.fromUserDoc(
    String userId,
    Map<String, dynamic> data,
  ) {
    return FollowUserProfile(
      userId: userId,
      username: _firstNonEmpty(
        data['username'],
        data['name'],
        data['displayName'],
        'Pet User',
      ),
      avatarUrl: _firstNonEmpty(
        data['photoUrl'],
        data['profileImageUrl'],
        data['photoURL'],
        '',
      ),
      isPremium: data['isPremium'] == true || data['premium'] == true,
    );
  }

  static String _firstNonEmpty(
    Object? first,
    Object? second,
    Object? third,
    String fallback,
  ) {
    for (final value in [first, second, third]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return fallback;
  }
}
