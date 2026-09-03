import 'dart:io';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/ui/shell/barky_bottom_nav.dart';
import 'package:barky_matches_fixed/ui/shell/barky_scaffold.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Phase 6 — the primary shell bottom navigation must stay visible while the
/// user scrolls any primary tab.
///
/// Before this fix, `BarkyScaffold` wrapped its body in a global
/// `NotificationListener<UserScrollNotification>` that called
/// `setBottomNavVisibility(false)` on `ScrollDirection.reverse` and `(true)` on
/// forward/idle, so the bar slid off-screen (`Offset(0, 1.5)`) and faded to
/// `opacity: 0` whenever the user scrolled down.
///
/// `AppState.setBottomNavVisibility`/`showBottomNav` are deliberately retained
/// as the explicit show/hide mechanism — only the scroll-driven mutation was
/// removed — so the last test here pins that the explicit path still works.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // BarkyScaffold renders BarkyAppBar, which reaches ChatService ->
  // FirebaseFirestore.instance during build. Mocking firebase_core is what
  // lets the real shell mount here; no network or Firestore call is made.
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  AppState buildAppState() {
    return AppState(
      favoriteDogs: <Dog>[],
      favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
      likesNotifier: ValueNotifier<Map<String, List<String>>>(
        <String, List<String>>{},
      ),
      onToggleFavorite: (_) async {},
      notificationService: NotificationService(),
      currentUserId: 'test-user',
    );
  }

  /// A tall scrollable standing in for a primary tab's content.
  Widget scrollableBody() {
    return ListView.builder(
      key: const Key('primary-tab-scrollable'),
      itemCount: 60,
      itemBuilder: (_, index) =>
          SizedBox(height: 80, child: Text('row $index')),
    );
  }

  Widget wrap(AppState appState, {NavTab tab = NavTab.home}) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BarkyScaffold(
          currentTab: tab,
          currentUserId: 'test-user',
          dogs: const <Dog>[],
          favoriteDogs: const <Dog>[],
          onToggleFavorite: (_) {},
          onNotificationTap: () {},
          body: scrollableBody(),
        ),
      ),
    );
  }

  /// Reads the rendered offset/opacity actually applied to the bottom bar, so
  /// the assertions prove the bar is on-screen and opaque — not merely that a
  /// boolean happens to be true.
  ({Offset offset, double opacity}) renderedNavState(WidgetTester tester) {
    final slide = tester.widget<AnimatedSlide>(
      find
          .descendant(
            of: find.byType(BarkyBottomNav),
            matching: find.byType(AnimatedSlide),
          )
          .first,
    );
    final opacity = tester.widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byType(BarkyBottomNav),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    return (offset: slide.offset, opacity: opacity.opacity);
  }

  /// Drives a drag in steps and runs [check] while the pointer is still down —
  /// i.e. while the scroll position is actively changing and
  /// `ScrollDirection` is reverse/forward rather than idle. This is the window
  /// in which the removed listener used to hide the bar; asserting only after
  /// `pumpAndSettle` would let `idle` restore it and hide the regression.
  Future<void> midDrag(
    WidgetTester tester,
    Offset totalDelta,
    void Function(String phase) check,
  ) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('primary-tab-scrollable'))),
    );
    const steps = 4;
    final step = Offset(totalDelta.dx / steps, totalDelta.dy / steps);

    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(step);
      await tester.pump();
      check('step $i');
    }

    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('downward (reverse) scroll keeps the bottom nav visible', (
    tester,
  ) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pump();

    expect(appState.showBottomNav, isTrue, reason: 'precondition');

    // Assert DURING the drag, not after pumpAndSettle: the removed listener
    // hid the bar only while ScrollDirection was `reverse`, and restored it on
    // `idle`. Settling first would mask the regression entirely.
    await midDrag(tester, const Offset(0, -200), (phase) {
      expect(appState.showBottomNav, isTrue, reason: 'mid-scroll ($phase)');
      final state = renderedNavState(tester);
      expect(state.offset, Offset.zero, reason: 'off-screen mid-scroll');
      expect(state.opacity, 1.0, reason: 'faded out mid-scroll');
    });

    expect(appState.showBottomNav, isTrue, reason: 'after settle');
  });

  testWidgets('upward (forward) scroll keeps the bottom nav visible', (
    tester,
  ) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pump();

    // Scroll down first so there is room to scroll back up.
    await tester.drag(
      find.byKey(const Key('primary-tab-scrollable')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    await midDrag(tester, const Offset(0, 150), (phase) {
      expect(appState.showBottomNav, isTrue, reason: 'mid-scroll ($phase)');
      final state = renderedNavState(tester);
      expect(state.offset, Offset.zero);
      expect(state.opacity, 1.0);
    });

    expect(appState.showBottomNav, isTrue);
  });

  testWidgets('idle / no scroll does not change visibility', (tester) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    expect(appState.showBottomNav, isTrue);
    expect(renderedNavState(tester).offset, Offset.zero);
  });

  testWidgets('repeated long scrolling never hides the bar', (tester) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      await midDrag(tester, const Offset(0, -200), (phase) {
        expect(appState.showBottomNav, isTrue, reason: 'drag $i ($phase)');
        expect(renderedNavState(tester).opacity, 1.0, reason: 'drag $i');
      });
    }

    final state = renderedNavState(tester);
    expect(state.offset, Offset.zero);
    expect(state.opacity, 1.0);
  });

  testWidgets('switching tabs after scrolling keeps the bar and the new tab', (
    tester,
  ) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pump();

    await midDrag(tester, const Offset(0, -200), (phase) {
      expect(appState.showBottomNav, isTrue, reason: 'mid-scroll ($phase)');
    });

    await tester.pumpWidget(wrap(appState, tab: NavTab.profile));
    await tester.pumpAndSettle();

    expect(appState.showBottomNav, isTrue);
    expect(renderedNavState(tester).offset, Offset.zero);

    final nav = tester.widget<BarkyBottomNav>(find.byType(BarkyBottomNav));
    expect(nav.currentTab, NavTab.profile, reason: 'selected tab preserved');
  });

  testWidgets('explicit setBottomNavVisibility still hides and restores', (
    tester,
  ) async {
    final appState = buildAppState();
    await tester.pumpWidget(wrap(appState));
    await tester.pumpAndSettle();

    appState.setBottomNavVisibility(false);
    await tester.pumpAndSettle();

    expect(appState.showBottomNav, isFalse);
    expect(renderedNavState(tester).opacity, 0.0);

    appState.setBottomNavVisibility(true);
    await tester.pumpAndSettle();

    expect(appState.showBottomNav, isTrue);
    expect(renderedNavState(tester).offset, Offset.zero);
    expect(renderedNavState(tester).opacity, 1.0);
  });

  test('BarkyScaffold no longer contains scroll-driven nav hiding', () {
    final source = File('lib/ui/shell/barky_scaffold.dart').readAsStringSync();

    // Strip comments so the explanatory note about the removed listener does
    // not make this guard pass or fail on prose.
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code.contains('NotificationListener<UserScrollNotification>'),
      isFalse,
      reason: 'the global scroll listener must not come back',
    );
    expect(
      code.contains('ScrollDirection.reverse'),
      isFalse,
      reason: 'scroll direction must not drive nav visibility',
    );
    expect(
      code.contains('setBottomNavVisibility(false)'),
      isFalse,
      reason: 'the shell must never hide the primary nav implicitly',
    );
  });
}
