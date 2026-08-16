// Unit tests for SocialPostService.toggleLike — the exact method reported
// in the runtime crash (SocialPostService.toggleLike, social_post_service.dart
// permission-denied). Uses FakeFirebaseFirestore (no real network/emulator)
// with an injected currentUserId resolver so FirebaseAuth.instance never
// needs to be touched.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/social/services/social_post_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('social_posts').doc('post-1').set({
      'userId': 'owner-uid',
      'caption': 'hello',
      'visibility': 'public',
      'moderationStatus': 'active',
      'isHidden': false,
      'likeCount': 0,
      'commentCount': 0,
    });
  });

  SocialPostService serviceFor(String? uid) {
    return SocialPostService(firestore: firestore, currentUserId: () => uid);
  }

  test('guest (no signed-in user) is a safe no-op', () async {
    final service = serviceFor(null);
    await service.toggleLike('post-1');

    final post = await firestore.collection('social_posts').doc('post-1').get();
    expect(post.data()!['likeCount'], 0);
  });

  test(
    'liking an eligible post creates the like doc and increments likeCount',
    () async {
      final service = serviceFor('other-uid');
      await service.toggleLike('post-1');

      final post = await firestore
          .collection('social_posts')
          .doc('post-1')
          .get();
      expect(post.data()!['likeCount'], 1);

      final like = await firestore
          .collection('post_likes')
          .doc('post-1_other-uid')
          .get();
      expect(like.exists, isTrue);
      expect(like.data()!['userId'], 'other-uid');
      expect(like.data()!['postId'], 'post-1');
    },
  );

  test(
    'tapping like again (unlike) removes the like doc and decrements likeCount',
    () async {
      final service = serviceFor('other-uid');
      await service.toggleLike('post-1');
      await service.toggleLike('post-1');

      final post = await firestore
          .collection('social_posts')
          .doc('post-1')
          .get();
      expect(post.data()!['likeCount'], 0);

      final like = await firestore
          .collection('post_likes')
          .doc('post-1_other-uid')
          .get();
      expect(like.exists, isFalse);
    },
  );

  test('likedStream reflects the current like state', () async {
    final service = serviceFor('other-uid');
    expect(await service.likedStream('post-1').first, isFalse);

    await service.toggleLike('post-1');
    expect(await service.likedStream('post-1').first, isTrue);

    await service.toggleLike('post-1');
    expect(await service.likedStream('post-1').first, isFalse);
  });

  test('a rapid duplicate tap while a toggle is already in flight is ignored, '
      'not double-applied', () async {
    final service = serviceFor('other-uid');

    // Fire two toggles back-to-back without awaiting the first. Without
    // the in-flight guard both would read "not liked" before either
    // writes, and both would apply a +1 batch, corrupting the count.
    final first = service.toggleLike('post-1');
    final second = service.toggleLike('post-1');
    await Future.wait([first, second]);

    final post = await firestore.collection('social_posts').doc('post-1').get();
    expect(
      post.data()!['likeCount'],
      1,
      reason: 'exactly one like should be recorded, not two',
    );

    final like = await firestore
        .collection('post_likes')
        .doc('post-1_other-uid')
        .get();
    expect(like.exists, isTrue);
  });

  test(
    'a failed toggle throws so the caller can catch it (never silently swallowed)',
    () async {
      final service = serviceFor('other-uid');

      // Updating a post document that does not exist mirrors what a denied/
      // failed server write looks like to the caller: the batch commit
      // throws instead of silently succeeding.
      await expectLater(
        () => service.toggleLike('missing-post'),
        throwsA(anything),
      );
    },
  );
}
