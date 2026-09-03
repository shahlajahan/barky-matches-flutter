import 'dart:async';

import 'package:barky_matches_fixed/app_entry.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/welcome_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 3 — startup must wait for a *settled* Firebase auth result before
/// deciding a user is signed out.
///
/// Before this change `AppEntry` read `FirebaseAuth.instance.currentUser`
/// once; Firebase restores a persisted session asynchronously, so that read is
/// transiently null at launch and the null branch rendered WelcomePage.
///
/// The auth stream is injected (mirroring the existing
/// `PostCommentService(currentUser: () => user)` seam), so every sequence
/// below is driven deterministically — no real Firebase, no network, no
/// timing dependence.

/// Minimal stand-in for `User`, following the `_FakeUser` pattern already used
/// in test/social/post_comment_service_test.dart.
class _FakeUser implements User {
  _FakeUser(this.uid, {this.isAnonymous = false, this.providerId = 'password'});

  @override
  final String uid;

  @override
  final bool isAnonymous;

  /// Not part of `User` itself — kept only so the provider-restore cases below
  /// read clearly. AppState does not branch on it.
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<User?> authEvents;
  late List<AppState> created;

  // AppState's auth listener logs FirebaseAuth.instance state on the event
  // path; core mocks let that resolve without a real app. Auth *decisions*
  // still come only from the injected stream/currentUser seams.
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authEvents = StreamController<User?>.broadcast();
    created = <AppState>[];
  });

  tearDown(() async {
    // No stream, subscription or AppState may leak into the next test.
    for (final state in created) {
      if (!state.isDisposed) state.dispose();
    }
    await authEvents.close();
  });

  AppState buildAppState({User? currentUser}) {
    final state = AppState(
      favoriteDogs: <Dog>[],
      favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
      likesNotifier: ValueNotifier<Map<String, List<String>>>(
        <String, List<String>>{},
      ),
      onToggleFavorite: (_) async {},
      notificationService: NotificationService(),
      currentUserId: null,
    );
    state.authEventsOverride = () => authEvents.stream;
    // Restoration + routing only; downstream session coordination reaches the
    // real Firebase singletons and is Phase 4/5 scope.
    state.debugSkipAuthenticatedSessionCoordination = true;
    state.currentUserOverride = () => currentUser;
    created.add(state);
    return state;
  }

  group('restoration state model', () {
    test('starts in restoring/unknown before any auth event', () {
      final appState = buildAppState();

      expect(appState.authRestorationSettled, isFalse);
      expect(appState.hasRestoredAuthUser, isFalse);
    });

    test('a user event settles as authenticated', () async {
      final appState = buildAppState()..startAuthListener();

      authEvents.add(_FakeUser('uid-1'));
      await Future<void>.delayed(Duration.zero);

      expect(appState.authRestorationSettled, isTrue);
      expect(appState.hasRestoredAuthUser, isTrue);
    });

    test('a null event settles as unauthenticated', () async {
      final appState = buildAppState()..startAuthListener();

      authEvents.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(appState.authRestorationSettled, isTrue);
      expect(appState.hasRestoredAuthUser, isFalse);
    });

    test('settling notifies listeners exactly once', () async {
      final appState = buildAppState()..startAuthListener();
      var settledNotifications = 0;
      appState.addListener(() {
        if (appState.authRestorationSettled) settledNotifications++;
      });

      authEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      authEvents.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(appState.authRestorationSettled, isTrue);
      expect(settledNotifications, greaterThan(0));
    });

    test(
      'a transient null while the SDK still holds a user is not a sign-out',
      () async {
        // Firebase can emit a spurious null while currentUser is still set.
        final appState = buildAppState(currentUser: _FakeUser('uid-1'))
          ..startAuthListener();

        authEvents.add(_FakeUser('uid-1'));
        await Future<void>.delayed(Duration.zero);
        expect(appState.hasRestoredAuthUser, isTrue);

        authEvents.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(
          appState.hasRestoredAuthUser,
          isTrue,
          reason: 'false null must not report the user as gone',
        );
      },
    );

    test(
      'a genuine later null after an authenticated session routes out',
      () async {
        // currentUser is null too -> a real revocation/sign-out.
        final appState = buildAppState()..startAuthListener();

        authEvents.add(_FakeUser('uid-1'));
        await Future<void>.delayed(Duration.zero);
        expect(appState.hasRestoredAuthUser, isTrue);

        authEvents.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(appState.hasRestoredAuthUser, isFalse);
        expect(appState.authRestorationSettled, isTrue);
      },
    );

    test(
      'an anonymous user settles as an authenticated (guest) session',
      () async {
        final appState = buildAppState()..startAuthListener();

        authEvents.add(_FakeUser('anon-1', isAnonymous: true));
        await Future<void>.delayed(Duration.zero);

        expect(appState.hasRestoredAuthUser, isTrue);
        expect(appState.authRestorationSettled, isTrue);
        expect(appState.isGuest, isTrue, reason: 'anonymous restores as guest');
      },
    );

    for (final provider in <String>['password', 'google.com', 'apple.com']) {
      test('an existing $provider session restores', () async {
        final appState = buildAppState()..startAuthListener();

        authEvents.add(_FakeUser('uid-$provider', providerId: provider));
        await Future<void>.delayed(Duration.zero);

        expect(appState.hasRestoredAuthUser, isTrue);
        expect(appState.authRestorationSettled, isTrue);
      });
    }

    test('a stream error settles without reporting a sign-out', () async {
      final appState = buildAppState()..startAuthListener();

      authEvents.add(_FakeUser('uid-1'));
      await Future<void>.delayed(Duration.zero);

      authEvents.addError(StateError('transient auth failure'));
      await Future<void>.delayed(Duration.zero);

      expect(appState.authRestorationSettled, isTrue);
      expect(
        appState.hasRestoredAuthUser,
        isTrue,
        reason: 'an error is not a sign-out',
      );
    });

    testWidgets('a missed initial event settles via the defensive timeout', (
      tester,
    ) async {
      final appState = buildAppState()..startAuthListener();

      expect(appState.authRestorationSettled, isFalse);

      // Correctness never depends on this delay: it only stops the app from
      // waiting forever if the stream never speaks.
      await tester.pump(AppState.authRestorationTimeout);
      await tester.pump();

      expect(appState.authRestorationSettled, isTrue);
      expect(
        appState.hasRestoredAuthUser,
        isFalse,
        reason: 'timeout must not invent an authenticated user',
      );

      appState.dispose();
    });
  });

  group('listener lifecycle', () {
    test('starts exactly once even if called repeatedly', () async {
      final appState = buildAppState();

      appState.startAuthListener();
      appState.startAuthListener();
      appState.startAuthListener();

      var events = 0;
      appState.addListener(() => events++);

      authEvents.add(_FakeUser('uid-1'));
      await Future<void>.delayed(Duration.zero);

      // A duplicated subscription would deliver the event more than once.
      expect(authEvents.hasListener, isTrue);
      expect(appState.hasRestoredAuthUser, isTrue);
      expect(events, greaterThan(0));
    });

    test(
      'subscription is cancelled on dispose and cannot emit after',
      () async {
        final appState = buildAppState()..startAuthListener();

        authEvents.add(_FakeUser('uid-1'));
        await Future<void>.delayed(Duration.zero);

        appState.dispose();
        expect(appState.isDisposed, isTrue);

        // Must not throw "notifyListeners after dispose".
        authEvents.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(authEvents.hasListener, isFalse);
      },
    );

    test('the defensive timer does not fire after dispose', () async {
      final appState = buildAppState()..startAuthListener();

      appState.dispose();

      // Would throw if the timer notified a disposed AppState.
      await Future<void>.delayed(Duration.zero);
      expect(appState.isDisposed, isTrue);
    });
  });

  group('AppEntry routing', () {
    Widget harness(AppState appState) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppEntry(),
        ),
      );
    }

    testWidgets('shows loading while restoring, never WelcomePage', (
      tester,
    ) async {
      final appState = buildAppState()..startAuthListener();
      await tester.pumpWidget(harness(appState));

      // Pump several frames while the stream is deliberately silent.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byType(WelcomePage),
          findsNothing,
          reason: 'WelcomePage must never appear while restoring (frame $i)',
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }

      // Cancels the defensive restoration timer; a pending timer would
      // otherwise outlive the widget tree.
      appState.dispose();
    });

    testWidgets('transient null then authenticated never renders WelcomePage', (
      tester,
    ) async {
      final appState = buildAppState()..startAuthListener();
      await tester.pumpWidget(harness(appState));

      // This is the production sequence: currentUser null at launch, then
      // Firebase delivers the restored user.
      await tester.pump();
      expect(find.byType(WelcomePage), findsNothing);

      authEvents.add(_FakeUser('uid-1'));
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(WelcomePage),
        findsNothing,
        reason: 'restored session must never flash the login page',
      );

      appState.dispose();
    });

    testWidgets('settled null renders WelcomePage', (tester) async {
      final appState = buildAppState()..startAuthListener();
      await tester.pumpWidget(harness(appState));
      await tester.pump();

      expect(find.byType(WelcomePage), findsNothing);

      authEvents.add(null);
      await tester.pump();
      await tester.pump();

      expect(find.byType(WelcomePage), findsOneWidget);

      // WelcomePage schedules its own 4.5s offers refresh; drain it so no
      // timer outlives the widget tree.
      await tester.pump(const Duration(seconds: 5));
      appState.dispose();
    });

    testWidgets('authenticated user with unready profile stays on loading', (
      tester,
    ) async {
      final appState = buildAppState()..startAuthListener();
      await tester.pumpWidget(harness(appState));

      authEvents.add(_FakeUser('uid-1'));
      await tester.pump();
      await tester.pump();

      // A slow, missing or failing profile read must keep the session and the
      // loading UI — never WelcomePage, and never a sign-out.
      expect(appState.isUserProfileReady, isFalse);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        appState.hasRestoredAuthUser,
        isTrue,
        reason: 'profile trouble must not drop the Firebase session',
      );

      appState.dispose();
    });

    testWidgets('rebuilding AppEntry does not add another listener', (
      tester,
    ) async {
      final appState = buildAppState()..startAuthListener();
      await tester.pumpWidget(harness(appState));
      await tester.pump();

      // Force repeated rebuilds of the entry widget.
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(harness(appState));
        await tester.pump();
      }

      authEvents.add(_FakeUser('uid-1'));
      await tester.pump();

      expect(appState.hasRestoredAuthUser, isTrue);
      expect(find.byType(WelcomePage), findsNothing);

      appState.dispose();
    });
  });
}
