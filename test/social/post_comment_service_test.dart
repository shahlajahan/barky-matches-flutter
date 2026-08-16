// Unit tests for PostCommentService.addComment.
//
// Comment creation now goes through the addSocialComment trusted callable
// (functions/src/social/addSocialCommentCore.js) rather than a direct
// Firestore write, because post_comments uses auto-generated IDs and
// firestore.rules has no way to prove a direct client write is atomically
// paired with its commentCount increment (unlike likes, which use the
// deterministic post_likes/{postId}_{uid} id). The actual create/
// increment/idempotency/concurrency behavior is covered by
// functions/test/addSocialComment.test.js against the real callable.
//
// What remains meaningfully testable at this layer — without a running
// Functions emulator — is the client-side short-circuit: guest is a
// no-op, and empty/oversized text is rejected before any network call is
// even attempted. `_ThrowingFunctions` proves that by failing loudly if
// PostCommentService ever tries to invoke the callable in those cases.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/social/services/post_comment_service.dart';

/// Minimal stand-in for `User` so tests never touch the real
/// `FirebaseAuth.instance`. Only `uid` is exercised by
/// PostCommentService.addComment before it short-circuits in these tests;
/// anything else throws via noSuchMethod.
class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A FirebaseFunctions stand-in that fails any attempt to actually call a
/// callable. Used for tests that must never reach the network call
/// (guest, empty text, oversized text all return/throw before that
/// point) — if PostCommentService regresses and calls it anyway, the test
/// fails loudly instead of silently passing.
class _ThrowingFunctions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('FirebaseFunctions must not be used for this case');
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  PostCommentService serviceFor(User? user) {
    return PostCommentService(
      firestore: firestore,
      functions: _ThrowingFunctions(),
      currentUser: () => user,
    );
  }

  test('guest (no signed-in user) is a safe no-op', () async {
    final service = serviceFor(null);
    // Would throw via _ThrowingFunctions if it reached the callable.
    await service.addComment(postId: 'post-1', text: 'hi');
  });

  test(
    'empty/whitespace-only content is rejected before any network call',
    () async {
      final service = serviceFor(_FakeUser('other-uid'));
      await expectLater(
        () => service.addComment(postId: 'post-1', text: '   '),
        throwsArgumentError,
      );
    },
  );

  test('oversized content is rejected before any network call', () async {
    final service = serviceFor(_FakeUser('other-uid'));
    final overLong = 'x' * (PostCommentService.kMaxCommentLength + 1);

    await expectLater(
      () => service.addComment(postId: 'post-1', text: overLong),
      throwsArgumentError,
    );
  });
}
