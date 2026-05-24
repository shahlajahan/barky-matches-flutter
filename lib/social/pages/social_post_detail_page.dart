import 'package:flutter/material.dart';

import '../models/social_post.dart';
import 'social_feed_page.dart';

class SocialPostDetailPage
    extends StatelessWidget {
  final SocialPost post;

  const SocialPostDetailPage({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Stack(
          children: [
            SocialFeedSinglePost(
              post: post,
            ),

            Positioned(
              top: 10,
              left: 10,

              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },

                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}