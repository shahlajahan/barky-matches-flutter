import 'package:flutter/material.dart';

import '../services/social_post_service.dart';
import '../models/social_post.dart';
import 'social_post_detail_page.dart';

class SocialPostRoutePage extends StatefulWidget {
  final String postId;

  const SocialPostRoutePage({super.key, required this.postId});

  @override
  State<SocialPostRoutePage> createState() => _SocialPostRoutePageState();
}

class _SocialPostRoutePageState extends State<SocialPostRoutePage> {
  late final Future<SocialPost?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = SocialPostService().getPublicPost(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SocialPost?>(
      future: _postFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final post = snapshot.data;
        if (snapshot.hasError || post == null) {
          return const Scaffold(
            body: Center(child: Text('This post is unavailable')),
          );
        }

        return SocialPostDetailPage(post: post);
      },
    );
  }
}
