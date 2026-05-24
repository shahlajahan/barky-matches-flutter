import 'package:flutter/material.dart';

import 'followers_list_page.dart';

class FollowingListPage extends StatelessWidget {
  final String userId;

  const FollowingListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return _FollowingListBody(userId: userId);
  }
}

class _FollowingListBody extends StatelessWidget {
  final String userId;

  const _FollowingListBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FollowUsersListPage(
      title: 'Following',
      userId: userId,
      collection: 'following',
      subcollection: 'userFollowing',
    );
  }
}
