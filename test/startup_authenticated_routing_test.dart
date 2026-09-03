import 'dart:async';
import 'dart:io';

import 'package:barky_matches_fixed/app_entry.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/auth_page.dart';
import 'package:barky_matches_fixed/core/debug/auth_boot_trace.dart';
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

/// Reproduces the ordering the physical iPhone trace proved:
///
///   current_user_snapshot after_firebase_init -> hasUser: true
///   first auth_event      -> hasUser: true, sdkCurrentUserPresent: true
///   restoration phase     -> authenticated within 15-69 ms
///   no signout anywhere
///
/// …yet the device still rendered Welcome/AuthPage. Firebase restoration was
/// never the defect; presentation was. These tests assert on the widget tree
/// across *every* frame, because the failure was a route that rendered even
/// though AppState held the correct authenticated phase.
class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<User?> authEvents;
  late List<AppState> created;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authEvents = StreamController<User?>.broadcast();
    created = <AppState>[];
    AuthBootTrace.resetForTest();
  });

  tearDown(() async {
    for (final state in created) {
      if (!state.isDisposed) state.dispose();
    }
    await authEvents.close();
    AuthBootTrace.resetForTest();
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
    state.currentUserOverride = () => currentUser;
    state.debugSkipAuthenticatedSessionCoordination = true;
    state.authRestorationTimeout = const Duration(seconds: 30);
    created.add(state);
    return state;
  }

  /// Mirrors main.dart: MaterialApp.home wraps AppEntry.
  Widget app(AppState appState) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Builder(
        builder: (context) {
          final locale = context.select<AppState, Locale>((s) => s.locale);
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppEntry(),
          );
        },
      ),
    );
  }

  void expectNoSignedOutSurface(WidgetTester tester, String when) {
    expect(
      find.byType(WelcomePage),
      findsNothing,
      reason:
          'WelcomePage must never render for an authenticated cold start '
          '($when)',
    );
    expect(
      find.byType(AuthPage),
      findsNothing,
      reason:
          'AuthPage must never render for an authenticated cold start '
          '($when)',
    );
  }

  testWidgets(
    'authenticated cold start never renders Welcome or AuthPage on any frame',
    (tester) async {
      // The device trace shows currentUser already present when the listener
      // attaches — restoration had already succeeded.
      final user = _FakeUser('cold-start-uid');
      final appState = buildAppState(currentUser: user);

      appState.startAuthListener();
      await tester.pumpWidget(app(appState));

      // Frame 0: before any auth event is delivered.
      expectNoSignedOutSurface(tester, 'first frame');

      // Deliver the authenticated event, checking every intermediate frame.
      authEvents.add(user);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expectNoSignedOutSurface(tester, 'frame $i after auth event');
      }

      expect(appState.authRestorationPhase, AuthRestorationPhase.authenticated);

      appState.dispose();
    },
  );

  testWidgets(
    'authenticated cold start reaches the authenticated destination',
    (tester) async {
      final user = _FakeUser('cold-start-uid');
      final appState = buildAppState(currentUser: user);

      appState.startAuthListener();
      await tester.pumpWidget(app(appState));

      authEvents.add(user);
      await tester.pump();
      await tester.pump();

      // Profile is not ready in this harness, so the correct destination is the
      // profile-readiness wait — never the signed-out entry point.
      expect(appState.authRestorationPhase, AuthRestorationPhase.authenticated);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expectNoSignedOutSurface(tester, 'after settling');

      appState.dispose();
    },
  );

  testWidgets('a genuine unauthenticated cold start still renders Welcome', (
    tester,
  ) async {
    final appState = buildAppState();

    appState.startAuthListener();
    await tester.pumpWidget(app(appState));
    await tester.pump();

    authEvents.add(null);
    await tester.pump();
    await tester.pump();

    expect(appState.authRestorationPhase, AuthRestorationPhase.unauthenticated);
    expect(
      find.byType(WelcomePage),
      findsOneWidget,
      reason: 'a real signed-out state must still reach WelcomePage',
    );

    await tester.pump(const Duration(seconds: 5));
    appState.dispose();
  });

  testWidgets('failed restoration still shows the retry state, not Welcome', (
    tester,
  ) async {
    final appState = buildAppState();

    appState.startAuthListener();
    await tester.pumpWidget(app(appState));
    await tester.pump();

    authEvents.addError(StateError('restoration failure'));
    await tester.pump();
    await tester.pump();

    expect(appState.authRestorationPhase, AuthRestorationPhase.failed);
    expectNoSignedOutSurface(tester, 'failed restoration');

    appState.dispose();
  });

  group('route ownership', () {
    testWidgets('MaterialApp.home resolves to the phase-aware AppEntry', (
      tester,
    ) async {
      // The defect was a second class named AppEntry declared in main.dart
      // whose build() returned WelcomePage unconditionally, shadowing the real
      // one because main.dart never imported app_entry.dart. This pins that
      // the routing widget actually mounted is the phase-aware one.
      final user = _FakeUser('cold-start-uid');
      final appState = buildAppState(currentUser: user);

      appState.startAuthListener();
      await tester.pumpWidget(app(appState));
      authEvents.add(user);
      await tester.pump();

      final entry = tester.widget<AppEntry>(find.byType(AppEntry));
      expect(entry, isA<AppEntry>());

      // The phase-aware AppEntry records its routing decision; the stub did
      // not, which is why app_entry_route was absent from every device trace.
      final routeEvents = AuthBootTrace.currentEvents
          .where((e) => e['event'] == 'app_entry_route')
          .toList();
      expect(
        routeEvents,
        isNotEmpty,
        reason: 'the mounted AppEntry must be the traced, phase-aware one',
      );
      expect(routeEvents.last['data']['destination'], isNot('welcome'));

      appState.dispose();
    });
  });

  group('route ownership source guard', () {
    test('main.dart declares no AppEntry of its own', () {
      // The defect: main.dart declared a second `AppEntry` returning
      // WelcomePage unconditionally. Because main.dart did not import
      // app_entry.dart, that local declaration won and the phase-aware
      // AppEntry was dead code. A widget test cannot see this, because it
      // imports app_entry.dart directly — so it is pinned here.
      final source = File('lib/main.dart').readAsStringSync();

      expect(
        RegExp(r'class\s+AppEntry\b').hasMatch(source),
        isFalse,
        reason: 'main.dart must not shadow the real AppEntry',
      );
      expect(
        source.contains("import 'app_entry.dart';"),
        isTrue,
        reason: 'main.dart must route through the phase-aware AppEntry',
      );
    });
  });

  group('trace privacy', () {
    test('no raw UID appears anywhere in the dump', () {
      const rawUid = 'j5kiZ8nbImRc8Qs4EO9WLmqA4Z32';

      // Every shape a UID could enter the trace through.
      AuthBootTrace.record(
        'auth_restoration_phase',
        data: <String, Object?>{
          'phase': 'authenticated',
          'reason': 'auth event uid=$rawUid',
        },
      );
      AuthBootTrace.record(
        'x',
        data: <String, Object?>{
          'uid': AuthBootTrace.redactUid(rawUid),
          'nested': <String>['uid=$rawUid'],
          'free': 'user $rawUid signed in',
        },
      );

      final dump = AuthBootTrace.export();

      expect(
        dump.contains(rawUid),
        isFalse,
        reason: 'the raw UID must never survive into the trace',
      );
      expect(dump, contains('<redacted>'));
    });

    test('scrubIdentifiers preserves short, non-identifying values', () {
      expect(AuthBootTrace.scrubIdentifiers('google.com'), 'google.com');
      expect(AuthBootTrace.scrubIdentifiers('password'), 'password');
      expect(AuthBootTrace.scrubIdentifiers('authenticated'), 'authenticated');
      // A redacted digest is short enough to survive.
      final digest = AuthBootTrace.redactUid('some-uid')!;
      expect(AuthBootTrace.scrubIdentifiers(digest), digest);
    });
  });
}
