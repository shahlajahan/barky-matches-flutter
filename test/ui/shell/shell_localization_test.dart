import 'dart:convert';
import 'dart:io';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/ui/shell/barky_bottom_nav.dart';
import 'package:barky_matches_fixed/ui/shell/barky_drawer.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 2 — the primary navigation shell (bottom bar + drawer) renders
/// localized strings in all four supported languages and updates in place
/// when the locale changes.
///
/// Each locale is asserted explicitly with its own expected text, so a test
/// cannot pass merely because English is the fallback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppState buildAppState({String? initialLanguageCode}) {
    return AppState(
      favoriteDogs: <Dog>[],
      favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
      likesNotifier: ValueNotifier<Map<String, List<String>>>(
        <String, List<String>>{},
      ),
      onToggleFavorite: (_) async {},
      notificationService: NotificationService(),
      currentUserId: 'test-user',
      initialLanguageCode: initialLanguageCode,
    );
  }

  /// Hosts a widget under the app's real localization delegates, driven by the
  /// same `context.select` on AppState.locale that main.dart uses.
  Widget host(AppState appState, Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Builder(
        builder: (context) {
          final locale = context.select<AppState, Locale>((s) => s.locale);
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              drawer: child is BarkyDrawer ? child : null,
              bottomNavigationBar: child is BarkyBottomNav ? child : null,
              body: const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }

  /// The drawer is a ListView; in the default 800px-tall test viewport the
  /// lower items are never built, so drawer tests need a taller surface. Reset
  /// after each test so the size cannot leak into another.
  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget bottomNav() => const BarkyBottomNav(currentTab: NavTab.home);

  Widget drawer() => const BarkyDrawer(
    currentUserId: 'test-user',
    dogs: <Dog>[],
    favoriteDogs: <Dog>[],
    onToggleFavorite: _noop,
  );

  // Expected rendered text per locale. Section headings are uppercased by the
  // drawer itself, so the expectations below apply .toUpperCase() too.
  const navLabels = <String, List<String>>{
    'en': ['Home', 'Favorites', 'Schedule', 'Profile'],
    'tr': ['Ana Sayfa', 'Favoriler', 'Program', 'Profil'],
    'fa': ['خانه', 'علاقه‌مندی‌ها', 'برنامه', 'پروفایل'],
    'ru': ['Главная', 'Избранное', 'Расписание', 'Профиль'],
  };

  const drawerItems = <String, List<String>>{
    'en': [
      'Home',
      'Send Feedback',
      'Report Problem',
      'FAQ',
      'Privacy Policy',
      'Terms of Service',
      'About Us',
      'Logout',
    ],
    'tr': [
      'Ana Sayfa',
      'Geri Bildirim Gönder',
      'Sorun Bildir',
      'SSS',
      'Gizlilik Politikası',
      'Hizmet Şartları',
      'Hakkımızda',
      'Çıkış Yap',
    ],
    'fa': [
      'خانه',
      'ارسال بازخورد',
      'گزارش مشکل',
      'سوالات متداول',
      'حریم خصوصی',
      'شرایط استفاده از خدمات',
      'درباره ما',
      'خروج',
    ],
    'ru': [
      'Главная',
      'Отправить отзыв',
      'Сообщить о проблеме',
      'Частые вопросы',
      'Политика конфиденциальности',
      'Условия использования',
      'О нас',
      'Выйти',
    ],
  };

  const drawerSections = <String, List<String>>{
    'en': ['Main', 'Support', 'Legal'],
    'tr': ['Ana Menü', 'Destek', 'Yasal'],
    'fa': ['منوی اصلی', 'پشتیبانی', 'قوانین'],
    'ru': ['Главное меню', 'Поддержка', 'Правовая информация'],
  };

  group('bottom navigation labels', () {
    for (final entry in navLabels.entries) {
      testWidgets('render in ${entry.key}', (tester) async {
        final appState = buildAppState(initialLanguageCode: entry.key);
        await tester.pumpWidget(host(appState, bottomNav()));
        await tester.pumpAndSettle();

        for (final label in entry.value) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '${entry.key}: expected "$label"',
          );
        }
      });
    }

    testWidgets('no hard-coded English leaks into a non-English locale', (
      tester,
    ) async {
      final appState = buildAppState(initialLanguageCode: 'tr');
      await tester.pumpWidget(host(appState, bottomNav()));
      await tester.pumpAndSettle();

      for (final english in navLabels['en']!) {
        expect(
          find.text(english),
          findsNothing,
          reason: 'English "$english" must not render under tr',
        );
      }
    });
  });

  group('drawer labels and section headings', () {
    Future<void> openDrawer(WidgetTester tester) async {
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();
    }

    for (final code in drawerItems.keys) {
      testWidgets('items render in $code', (tester) async {
        await useTallSurface(tester);
        final appState = buildAppState(initialLanguageCode: code);
        await tester.pumpWidget(host(appState, drawer()));
        await tester.pumpAndSettle();
        await openDrawer(tester);

        for (final label in drawerItems[code]!) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '$code: expected item "$label"',
          );
        }
      });

      testWidgets('section headings render in $code', (tester) async {
        await useTallSurface(tester);
        final appState = buildAppState(initialLanguageCode: code);
        await tester.pumpWidget(host(appState, drawer()));
        await tester.pumpAndSettle();
        await openDrawer(tester);

        for (final heading in drawerSections[code]!) {
          expect(
            find.text(heading.toUpperCase()),
            findsOneWidget,
            reason: '$code: expected heading "${heading.toUpperCase()}"',
          );
        }
      });
    }

    testWidgets('no hard-coded English section heading under tr', (
      tester,
    ) async {
      await useTallSurface(tester);
      final appState = buildAppState(initialLanguageCode: 'tr');
      await tester.pumpWidget(host(appState, drawer()));
      await tester.pumpAndSettle();
      await openDrawer(tester);

      for (final english in drawerSections['en']!) {
        expect(find.text(english.toUpperCase()), findsNothing);
      }
    });
  });

  group('live locale switching', () {
    testWidgets('mounted bottom navigation updates immediately', (
      tester,
    ) async {
      final appState = buildAppState(initialLanguageCode: 'en');
      await tester.pumpWidget(host(appState, bottomNav()));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      await appState.setLocale('tr');
      await tester.pumpAndSettle();

      expect(find.text('Ana Sayfa'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await appState.setLocale('ru');
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Ana Sayfa'), findsNothing);
    });

    testWidgets('mounted drawer updates immediately', (tester) async {
      await useTallSurface(tester);
      final appState = buildAppState(initialLanguageCode: 'en');
      await tester.pumpWidget(host(appState, drawer()));
      await tester.pumpAndSettle();

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('MAIN'), findsOneWidget);

      // Drawer stays open while the locale changes.
      await appState.setLocale('fa');
      await tester.pumpAndSettle();

      expect(find.text('خروج'), findsOneWidget);
      expect(find.text('منوی اصلی'.toUpperCase()), findsOneWidget);
      expect(find.text('Logout'), findsNothing);
    });
  });

  group('directionality', () {
    testWidgets('Persian renders RTL', (tester) async {
      final appState = buildAppState(initialLanguageCode: 'fa');
      await tester.pumpWidget(host(appState, bottomNav()));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('خانه'))),
        TextDirection.rtl,
      );
    });

    for (final code in <String, String>{
      'en': 'Home',
      'tr': 'Ana Sayfa',
      'ru': 'Главная',
    }.entries) {
      testWidgets('${code.key} renders LTR', (tester) async {
        final appState = buildAppState(initialLanguageCode: code.key);
        await tester.pumpWidget(host(appState, bottomNav()));
        await tester.pumpAndSettle();

        expect(
          Directionality.of(tester.element(find.text(code.value))),
          TextDirection.ltr,
        );
      });
    }
  });

  group('behaviour preserved', () {
    testWidgets('tapping a localized tab selects the same NavTab', (
      tester,
    ) async {
      final appState = buildAppState(initialLanguageCode: 'tr');
      await tester.pumpWidget(host(appState, bottomNav()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(appState.currentTab, NavTab.profile);

      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      expect(appState.currentTab, NavTab.favorites);

      await tester.tap(find.text('Program'));
      await tester.pumpAndSettle();
      expect(appState.currentTab, NavTab.playdateScheduling);
    });

    testWidgets('drawer item still triggers its action', (tester) async {
      await useTallSurface(tester);
      final appState = buildAppState(initialLanguageCode: 'tr');
      await tester.pumpWidget(host(appState, drawer()));
      await tester.pumpAndSettle();

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      // "Sorun Bildir" -> profile tab + reportProblem sub-page.
      await tester.tap(find.text('Sorun Bildir'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(appState.currentTab, NavTab.profile);
      expect(appState.profileSubPage, ProfileSubPage.reportProblem);
    });

    testWidgets('icons and item counts are unchanged', (tester) async {
      await useTallSurface(tester);
      final appState = buildAppState(initialLanguageCode: 'ru');
      await tester.pumpWidget(host(appState, drawer()));
      await tester.pumpAndSettle();

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      // 8 tiles + 3 section headings, same as before localization.
      expect(find.byType(ListTile), findsNWidgets(8));
    });
  });

  group('ARB integrity', () {
    Map<String, dynamic> arb(String code) =>
        json.decode(File('lib/l10n/app_$code.arb').readAsStringSync());

    test('all four ARB files share an identical key set', () {
      Set<String> keys(String code) =>
          arb(code).keys.where((k) => !k.startsWith('@')).toSet();

      final en = keys('en');
      for (final code in ['tr', 'fa', 'ru']) {
        expect(keys(code), en, reason: '$code key set must match en');
      }
    });

    test('every shell key is present and non-empty in all locales', () {
      const shellKeys = <String>[
        'homeNavItem',
        'favoritesNavItem',
        'scheduleNavItem',
        'profileNavItem',
        'drawerSectionMain',
        'drawerSectionSupport',
        'drawerSectionLegal',
        'homeMenuItem',
        'sendFeedback',
        'userProfileReportProblem',
        'faqMenuItem',
        'privacyPolicyLabel',
        'termsOfServiceTitle',
        'aboutUsTitle',
        'logoutMenuItem',
      ];

      for (final code in ['en', 'tr', 'fa', 'ru']) {
        final data = arb(code);
        for (final key in shellKeys) {
          expect(data.containsKey(key), isTrue, reason: '$code missing $key');
          expect(
            (data[key] as String).trim(),
            isNotEmpty,
            reason: '$code has empty $key',
          );
        }
      }
    });

    test('non-English shell values are actually translated', () {
      // Guards against a locale silently keeping the English string.
      const mustDiffer = <String>[
        'homeNavItem',
        'scheduleNavItem',
        'drawerSectionSupport',
        'logoutMenuItem',
      ];

      final en = arb('en');
      for (final code in ['tr', 'fa', 'ru']) {
        final data = arb(code);
        for (final key in mustDiffer) {
          expect(
            data[key],
            isNot(en[key]),
            reason: '$code.$key is still the English value',
          );
        }
      }
    });
  });

  group('source guards', () {
    test('no hard-coded English labels remain in the two shell widgets', () {
      const files = <String, List<String>>{
        'lib/ui/shell/barky_bottom_nav.dart': [
          "'Home'",
          "'Favorites'",
          "'Schedule'",
          "'Profile'",
        ],
        'lib/ui/shell/barky_drawer.dart': [
          '"Main"',
          '"Support"',
          '"Legal"',
          '"Home"',
          '"Send Feedback"',
          '"Report Problem"',
          '"FAQ"',
          '"Privacy Policy"',
          '"Terms of Service"',
          '"About Us"',
          '"Logout"',
        ],
      };

      files.forEach((path, literals) {
        final source = File(path).readAsStringSync();
        for (final literal in literals) {
          expect(
            source.contains(literal),
            isFalse,
            reason: '$path still contains hard-coded $literal',
          );
        }
      });
    });
  });
}

void _noop(Dog _) {}
