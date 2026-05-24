import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/social_post.dart';
import '../pages/social_post_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserPostsGrid extends StatelessWidget {
  final String userId;

  const UserPostsGrid({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    debugPrint("🔥 USER POSTS QUERY");
    debugPrint("🔥 userId = $userId");
    debugPrint("🔥 collection = social_posts");
    debugPrint("🔥 orderBy = createdAt");

    final query = FirebaseFirestore.instance
        .collection('social_posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    debugPrint("🔥 QUERY READY");

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),

      builder: (context, snapshot) {
        debugPrint("🔥 USER POSTS STATE = ${snapshot.connectionState}");

        debugPrint("🔥 USER POSTS HAS ERROR = ${snapshot.hasError}");

        if (snapshot.hasError) {
          debugPrint("🔥 USER POSTS ERROR = ${snapshot.error}");

          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs
            .map((doc) => SocialPost.fromFirestore(doc))
            .toList();

        debugPrint("🔥 USER POSTS COUNT = ${posts.length}");

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30),

            child: Center(
              child: Text(
                'No posts yet',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          padding: const EdgeInsets.all(2),

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),

          itemCount: posts.length,

          itemBuilder: (context, index) {
            final post = posts[index];
            final media = post.media.isNotEmpty ? post.media.first : null;
            final previewUrl =
                media?.previewUrl ??
                (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : '');

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SocialPostDetailPage(post: post),
                  ),
                );
              },

              child: Hero(
                tag: post.id,

                child: CachedNetworkImage(
                  imageUrl: previewUrl,

                  fit: BoxFit.cover,

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
                          Icons.image_not_supported,
                          color: Colors.white38,
                          size: 42,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
