// Widget tests for PetploreAvatar — the shared safe-avatar component
// introduced to fix the reported runtime crash:
//   HttpException: Invalid statusCode: 403
//   ...CachedNetworkImageProvider... "Unhandled FlutterError captured"
// for a revoked/expired Firebase Storage profile-image download token.
//
// Uses a fully in-memory, no-op-storage CacheManager (see
// _fake_avatar_network.dart) so nothing here ever touches the real
// network, sqflite, or path_provider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/social/widgets/petplore_avatar.dart';

import '_fake_avatar_network.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('1. empty avatar URL renders the fallback, no network fetch', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: '',
          cacheManager: fakeAvatarCacheManager(neverCalledResponder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
    // No CachedNetworkImage was ever built for an empty URL (the widget
    // short-circuits before reaching it), so there's no Image widget at
    // all here — unlike the error-response tests below, where
    // CachedNetworkImage internally keeps an Image widget in the tree
    // even while displaying errorWidget, so checking for its absence
    // isn't a meaningful signal there.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('2. null avatar URL renders the fallback, no network fetch', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: null,
          cacheManager: fakeAvatarCacheManager(neverCalledResponder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
  });

  testWidgets('3. a malformed URL falls back safely', (tester) async {
    final cacheManager = fakeAvatarCacheManager((url) {
      throw const FormatException('Invalid URL');
    });

    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: 'not a valid url at all',
          cacheManager: cacheManager,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
  });

  testWidgets('4. an HTTP 403 response falls back safely (the reported bug)', (
    tester,
  ) async {
    final cacheManager = fakeAvatarCacheManager(
      (url) async => FakeAvatarResponse(statusCode: 403),
    );

    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: 'https://firebasestorage.example.test/revoked.jpg',
          cacheManager: cacheManager,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
  });

  testWidgets('5. an HTTP 404 response falls back safely', (tester) async {
    final cacheManager = fakeAvatarCacheManager(
      (url) async => FakeAvatarResponse(statusCode: 404),
    );

    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: 'https://example.test/deleted.jpg',
          cacheManager: cacheManager,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
  });

  testWidgets('6. a successful response renders the image, not the fallback', (
    tester,
  ) async {
    final cacheManager = fakeAvatarCacheManager(
      (url) async => FakeAvatarResponse(statusCode: 200, bytes: onePixelPng),
    );

    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: 'https://example.test/ok.jpg',
          cacheManager: cacheManager,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(LucideIcons.dog), findsNothing);
  });

  testWidgets('7. rebuilding after a failure does not throw again', (
    tester,
  ) async {
    var callCount = 0;
    final cacheManager = fakeAvatarCacheManager((url) async {
      callCount += 1;
      return FakeAvatarResponse(statusCode: 403);
    });

    final widget = host(
      PetploreAvatar(
        imageUrl: 'https://example.test/still-broken.jpg',
        cacheManager: cacheManager,
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);
    expect(tester.takeException(), isNull);

    // Force a second, independent build pass (a feed rebuild in
    // production) against the same failing URL.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.dog), findsOneWidget);
    expect(callCount, greaterThanOrEqualTo(1));
  });

  testWidgets(
    '8. multiple avatars sharing the same failed URL all fall back, no exception escapes',
    (tester) async {
      final cacheManager = fakeAvatarCacheManager(
        (url) async => FakeAvatarResponse(statusCode: 403),
      );
      const brokenUrl = 'https://example.test/shared-broken.jpg';

      await tester.pumpWidget(
        host(
          ListView(
            children: List.generate(
              5,
              (_) => PetploreAvatar(
                imageUrl: brokenUrl,
                cacheManager: cacheManager,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleAvatarCacheTimers(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(LucideIcons.dog), findsNWidgets(5));
    },
  );

  testWidgets('a valid URL keeps rendering the image (regression guard)', (
    tester,
  ) async {
    final cacheManager = fakeAvatarCacheManager(
      (url) async => FakeAvatarResponse(statusCode: 200, bytes: onePixelPng),
    );

    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: 'https://example.test/valid.jpg',
          radius: 30,
          cacheManager: cacheManager,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleAvatarCacheTimers(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the avatar exposes an accessible semantic label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        PetploreAvatar(
          imageUrl: null,
          semanticLabel: 'Ada avatar',
          cacheManager: fakeAvatarCacheManager(neverCalledResponder),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Ada avatar'), findsOneWidget);
    handle.dispose();
  });
}
