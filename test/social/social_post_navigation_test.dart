import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/social/models/social_post.dart';
import 'package:barky_matches_fixed/social/pages/social_post_detail_page.dart';
import 'package:barky_matches_fixed/social/pages/social_post_route_page.dart';
import 'package:barky_matches_fixed/welcome_page.dart';

SocialPost _post() {
  return SocialPost(
    id: 'post-1',
    userId: 'user-1',
    media: const [],
    mediaUrls: const [],
    mediaType: 'image',
    caption: 'A shared post',
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

AppState _appState() {
  return AppState(
    favoriteDogs: const <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>({}),
    onToggleFavorite: (_) {},
    notificationService: NotificationService(),
  );
}

Widget _host(Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: _appState(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _NavigationHost extends StatefulWidget {
  final bool external;
  final bool cold;

  const _NavigationHost({required this.external, this.cold = false});

  @override
  State<_NavigationHost> createState() => _NavigationHostState();
}

class _NavigationHostState extends State<_NavigationHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.cold) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SocialPostDetailPage(
            post: _post(),
            openedFromExternalShare: widget.external,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => widget.cold
            ? SocialPostDetailPage(
                post: _post(),
                openedFromExternalShare: widget.external,
              )
            : const Scaffold(body: Center(child: Text('Previous Petplore'))),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
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

  test('external and internal post routes have independent share flags', () {
    expect(
      const SocialPostRoutePage(
        postId: 'external',
        openedFromExternalShare: true,
      ).openedFromExternalShare,
      isTrue,
    );
    expect(
      const SocialPostRoutePage(postId: 'internal').openedFromExternalShare,
      isFalse,
    );
    expect(
      SocialPostDetailPage(post: _post()).openedFromExternalShare,
      isFalse,
    );
  });

  testWidgets('external Back clears the protected stack to WelcomePage', (
    tester,
  ) async {
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is FirebaseException) return;
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    await tester.pumpWidget(_host(const _NavigationHost(external: true)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Previous Petplore'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('cold unauthenticated external Back reaches WelcomePage', (
    tester,
  ) async {
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is FirebaseException) return;
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    await tester.pumpWidget(
      _host(const _NavigationHost(external: true, cold: true)),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Previous Petplore'), findsNothing);
  });

  testWidgets('internal Back still returns to the previous Petplore route', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const _NavigationHost(external: false)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Previous Petplore'), findsOneWidget);
    expect(find.byType(SocialPostDetailPage), findsNothing);
  });
}
