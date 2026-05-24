import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/social_post.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'social_post_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPostsPage extends StatelessWidget {
  const SavedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,

      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('saved_posts')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDocs = snapshot.data!.docs;

          if (savedDocs.isEmpty) {
            return const Center(
              child: Text(
                'No saved posts yet',

                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final postIds = savedDocs.map((e) => e['postId'] as String).toList();

          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('social_posts')
                .where(FieldPath.documentId, whereIn: postIds)
                .get(),

            builder: (context, postSnapshot) {
              if (!postSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = postSnapshot.data!.docs
                  .map((doc) => SocialPost.fromFirestore(doc))
                  .toList();

              return GridView.builder(
                padding: const EdgeInsets.all(2),

                itemCount: posts.length,

                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),

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
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
