import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';

/// Entitlement coverage for the Business quick action.
///
/// `UserProfilePage._buildRegisterBusinessButton` gates on exactly one
/// expression — `appState.canRegisterBusiness` — and shows the
/// "Unlock Business Features" upgrade sheet when it is false. Mounting the
/// whole profile page requires Firebase Auth, Firestore and Hive, so these
/// tests drive a **real** [AppState] carrying a **real** [UserSubscription]
/// and assert on the same shipping getter the button consults. The
/// subscription is built by the production `UserSubscription.fromMap`
/// parser, so the cache round trip that caused the reported false negative
/// is exercised end to end.
void main() {
  AppState buildAppState() => AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: 'test-user',
  );

  /// Mirrors the button's own branch: the upgrade sheet is shown when, and
  /// only when, `canRegisterBusiness` is false.
  Future<bool> upgradeSheetWouldShow(
    WidgetTester tester,
    AppState appState,
  ) async {
    late bool wouldShow;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<AppState>(
              builder: (context, state, _) {
                wouldShow = !state.canRegisterBusiness;
                return Text(
                  wouldShow ? 'Unlock Business Features' : 'Register Business',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wouldShow;
  }

  final future = DateTime.now().add(const Duration(days: 30));
  final past = DateTime.now().subtract(const Duration(days: 1));

  testWidgets(
    'active Gold restored from the ISO-8601 cache does NOT show the upgrade sheet',
    (tester) async {
      final appState = buildAppState();
      // Exactly the shape `cleanDeep` writes into the Hive cache.
      appState.debugSetSubscription(
        UserSubscription.fromMap({
          'plan': 'gold',
          'status': 'active',
          'expiresAt': future.toIso8601String(),
          'source': 'admin_grant',
        }),
      );

      expect(appState.isGold, isTrue);
      expect(appState.canRegisterBusiness, isTrue);
      expect(await upgradeSheetWouldShow(tester, appState), isFalse);
      expect(find.text('Unlock Business Features'), findsNothing);
      expect(find.text('Register Business'), findsOneWidget);
    },
  );

  testWidgets(
    'a cold start with no entitlement still shows the upgrade sheet',
    (tester) async {
      final appState = buildAppState();
      // AppState's own default — no cache, no successful read.
      expect(appState.canRegisterBusiness, isFalse);
      expect(await upgradeSheetWouldShow(tester, appState), isTrue);
      expect(find.text('Unlock Business Features'), findsOneWidget);
    },
  );

  testWidgets('expired Gold shows the upgrade sheet', (tester) async {
    final appState = buildAppState();
    appState.debugSetSubscription(
      UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': past.toIso8601String(),
      }),
    );

    expect(appState.isGold, isFalse);
    expect(await upgradeSheetWouldShow(tester, appState), isTrue);
  });

  testWidgets('Gold without any expiry shows the upgrade sheet', (
    tester,
  ) async {
    final appState = buildAppState();
    appState.debugSetSubscription(
      UserSubscription.fromMap({'plan': 'gold', 'status': 'active'}),
    );

    expect(appState.canRegisterBusiness, isFalse);
    expect(await upgradeSheetWouldShow(tester, appState), isTrue);
  });

  testWidgets('Premium does not unlock business registration', (tester) async {
    final appState = buildAppState();
    appState.debugSetSubscription(
      UserSubscription.fromMap({
        'plan': 'premium',
        'status': 'active',
        'expiresAt': future.toIso8601String(),
      }),
    );

    expect(appState.isPremium, isTrue);
    expect(appState.canRegisterBusiness, isFalse);
    expect(await upgradeSheetWouldShow(tester, appState), isTrue);
  });

  testWidgets(
    'a later authoritative read replaces degraded state and rebuilds the UI',
    (tester) async {
      final appState = buildAppState();
      // Degraded startup: labels only, no expiry — correctly fails closed.
      appState.debugSetSubscription(
        UserSubscription.fromMap({'plan': 'gold', 'status': 'active'}),
      );
      expect(await upgradeSheetWouldShow(tester, appState), isTrue);
      expect(find.text('Unlock Business Features'), findsOneWidget);

      // Firestore recovers and delivers the authoritative record.
      appState.debugSetSubscription(
        UserSubscription.fromMap({
          'plan': 'gold',
          'status': 'active',
          'expiresAt': future.toIso8601String(),
        }),
      );
      await tester.pumpAndSettle();

      expect(appState.canRegisterBusiness, isTrue);
      expect(find.text('Unlock Business Features'), findsNothing);
      expect(find.text('Register Business'), findsOneWidget);
    },
  );

  testWidgets('server cancellation after a cached active state fails closed', (
    tester,
  ) async {
    final appState = buildAppState();
    appState.debugSetSubscription(
      UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': future.toIso8601String(),
      }),
    );
    expect(appState.canRegisterBusiness, isTrue);

    appState.debugSetSubscription(
      UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'cancelled',
        'expiresAt': future.toIso8601String(),
      }),
    );
    await tester.pumpAndSettle();

    expect(appState.canRegisterBusiness, isFalse);
    expect(await upgradeSheetWouldShow(tester, appState), isTrue);
  });

  testWidgets('subscription eligibility is independent of business state', (
    tester,
  ) async {
    final appState = buildAppState();
    appState.debugSetSubscription(
      UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': future.toIso8601String(),
      }),
    );

    // An existing business/request routes elsewhere in the page; it must not
    // be conflated with the subscription predicate.
    appState.setBusinessStatus('pending');
    expect(appState.canRegisterBusiness, isTrue);

    appState.clearBusinessState();
    expect(appState.canRegisterBusiness, isTrue);
  });
}
