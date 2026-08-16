// Widget tests for CommentsBottomSheet — the UI reported as producing
// "COMMENT ERROR: [cloud_firestore/permission-denied]" with no user-facing
// feedback. Exercises the real widget (not a re-implementation) against an
// injected PostCommentService backed by FakeFirebaseFirestore, plus a
// throwing stand-in to prove the failure path is caught and surfaced.
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/social/models/social_post.dart';
import 'package:barky_matches_fixed/social/services/post_comment_service.dart';
import 'package:barky_matches_fixed/social/widgets/comments_bottom_sheet.dart';

import '_fake_avatar_network.dart';

/// All of these PostCommentService subclasses override addComment
/// entirely and never touch FirebaseFunctions, but the base constructor's
/// `functions` parameter still needs *some* value so its default
/// expression (`FirebaseFunctions.instanceFor(...)`, which requires a
/// real initialized Firebase app) is never evaluated.
class _NeverUsedFunctions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('FirebaseFunctions must not be used in this test');
}

class _ThrowingCommentService extends PostCommentService {
  _ThrowingCommentService()
    : super(
        firestore: FakeFirebaseFirestore(),
        functions: _NeverUsedFunctions(),
      );

  int callCount = 0;

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    callCount += 1;
    throw Exception('permission-denied');
  }
}

SocialPost _post() {
  return SocialPost(
    id: 'post-1',
    userId: 'owner-uid',
    media: const [],
    mediaUrls: const [],
    mediaType: 'image',
    caption: 'A post',
    createdAt: DateTime(2026),
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    saveCount: 0,
    viewCount: 0,
    visibility: 'public',
    moderationStatus: 'active',
    isHidden: false,
    reportCount: 0,
    tags: const [],
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Official FlutterFire test helper: no real platform plugin is
    // registered in a plain `flutter_test` VM run, so
    // `Firebase.initializeApp()` alone does not make `Firebase.app()`
    // (and therefore `FirebaseAuth.instance`, used by
    // CommentsBottomSheet's own comment-ownership check) succeed without
    // this — see
    // package:firebase_core_platform_interface/src/pigeon/mocks.dart.
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:ios:test',
          messagingSenderId: '1234567890',
          projectId: 'test-project',
        ),
      );
    } catch (_) {
      // The shared test process may already have initialized Firebase.
    }
  });

  testWidgets(
    'a successful comment clears the input and resets the sending state',
    (tester) async {
      final successService = _SucceedingCommentService(FakeFirebaseFirestore());

      await tester.pumpWidget(
        _host(
          CommentsBottomSheet(post: _post(), commentService: successService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('hello world'), findsNothing); // cleared from the input
      expect(successService.callCount, 1);
    },
  );

  testWidgets(
    'a failed comment shows a controlled error, keeps the draft, and never '
    'throws unhandled',
    (tester) async {
      final service = _ThrowingCommentService();

      await tester.pumpWidget(
        _host(CommentsBottomSheet(post: _post(), commentService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'my draft comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // No unhandled exception escaped past the widget.
      expect(tester.takeException(), isNull);
      // Draft text is retained, not lost, on failure.
      expect(find.text('my draft comment'), findsOneWidget);
      // A controlled, localized error message was shown (not a raw
      // Firebase exception string).
      expect(find.text('Something went wrong'), findsOneWidget);
      // Sending indicator reset; the send icon is interactive again.
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(service.callCount, 1);
    },
  );

  testWidgets('empty input does not attempt to send', (tester) async {
    final service = _ThrowingCommentService();

    await tester.pumpWidget(
      _host(CommentsBottomSheet(post: _post(), commentService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(service.callCount, 0);
  });

  testWidgets(
    'the send control is disabled while a request is in flight, so a rapid '
    'second tap cannot issue a duplicate request',
    (tester) async {
      final service = _SlowCommentService();

      await tester.pumpWidget(
        _host(CommentsBottomSheet(post: _post(), commentService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));

      // While the first request is in flight, the send icon is replaced by
      // a progress indicator and cannot be tapped again — there is no
      // enabled send control to accidentally double-fire.
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);

      service.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(service.callCount, 1);
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Integration coverage for the comment-author avatar (PetploreAvatar),
  // exercised through the real CommentsBottomSheet — not a synthetic
  // reproduction — with an in-memory fake image cache manager so no real
  // network call is made. Proves a broken avatar URL degrades gracefully
  // and never interferes with the comment submission it sits next to.
  // ─────────────────────────────────────────────────────────────────────

  testWidgets(
    '9. a comment with a broken avatar URL falls back safely (no unhandled exception)',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('post_comments').doc('comment-1').set({
        'postId': 'post-1',
        'userId': 'other-uid',
        'username': 'Other',
        'userPhotoUrl': 'https://example.test/broken-avatar.jpg',
        'text': 'hello',
        'createdAt': DateTime(2026),
        'moderationStatus': 'active',
        'isHidden': false,
      });
      final service = _SucceedingCommentService(firestore);
      final avatarCacheManager = fakeAvatarCacheManager(
        (url) async => FakeAvatarResponse(statusCode: 403),
      );

      await tester.pumpWidget(
        _host(
          CommentsBottomSheet(
            post: _post(),
            commentService: service,
            avatarCacheManager: avatarCacheManager,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleAvatarCacheTimers(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('hello'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    },
  );

  testWidgets(
    '10/12. a broken comment avatar does not block submitting a new comment, '
    'and never itself triggers a comment-service call',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('post_comments').doc('comment-1').set({
        'postId': 'post-1',
        'userId': 'other-uid',
        'username': 'Other',
        'userPhotoUrl': 'https://example.test/broken-avatar.jpg',
        'text': 'hello',
        'createdAt': DateTime(2026),
        'moderationStatus': 'active',
        'isHidden': false,
      });
      final service = _SucceedingCommentService(firestore);
      final avatarCacheManager = fakeAvatarCacheManager(
        (url) async => FakeAvatarResponse(statusCode: 403),
      );

      await tester.pumpWidget(
        _host(
          CommentsBottomSheet(
            post: _post(),
            commentService: service,
            avatarCacheManager: avatarCacheManager,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleAvatarCacheTimers(tester);

      // The avatar's own failure/fallback must not have called addComment.
      expect(service.callCount, 0);

      // Feed/comment actions remain fully functional alongside the
      // broken avatar.
      await tester.enterText(find.byType(TextField), 'still works');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(service.callCount, 1);
    },
  );
}

class _SucceedingCommentService extends PostCommentService {
  _SucceedingCommentService(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, functions: _NeverUsedFunctions());

  int callCount = 0;

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    callCount += 1;
  }
}

class _SlowCommentService extends PostCommentService {
  _SlowCommentService()
    : super(
        firestore: FakeFirebaseFirestore(),
        functions: _NeverUsedFunctions(),
      );

  int callCount = 0;
  final List<void Function()> _pending = [];

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    callCount += 1;
    final completer = Completer<void>();
    _pending.add(completer.complete);
    await completer.future;
  }

  void complete() {
    for (final done in _pending) {
      done();
    }
    _pending.clear();
  }
}
