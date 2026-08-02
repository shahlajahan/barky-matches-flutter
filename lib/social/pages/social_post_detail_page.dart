import 'package:flutter/material.dart';

import '../models/social_post.dart';
import 'petplore_page.dart';
import 'social_feed_page.dart';

class SocialPostDetailPage extends StatelessWidget {
  final SocialPost post;

  const SocialPostDetailPage({super.key, required this.post});

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/petplore'),
        builder: (_) => const PetplorePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,

        body: SafeArea(
          child: Stack(
            children: [
              SocialFeedSinglePost(post: post),

              Positioned(
                top: 10,
                left: 10,

                child: IconButton(
                  onPressed: () => _goBack(context),

                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
