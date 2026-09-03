import 'dart:io';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1 — one canonical locale mechanism owned by AppState.
///
/// Startup priority: valid saved preference -> supported device locale ->
/// English. Supported languages are exactly en/fa/ru/tr.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Every test starts from an empty preference store so a locale selected
    // by one test can never leak into another.
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

  group('device locale resolution (no saved preference)', () {
    // Device locales are passed explicitly rather than read from the platform,
    // so these never depend on the machine's real locale.
    test('tr_TR device locale resolves to tr', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('tr', 'TR')],
        ),
        'tr',
      );
    });

    test('fa_IR device locale resolves to fa', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('fa', 'IR')],
        ),
        'fa',
      );
    });

    test('ru_RU device locale resolves to ru', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('ru', 'RU')],
        ),
        'ru',
      );
    });

    test('en_US and en_GB device locales resolve to en', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('en', 'US')],
        ),
        'en',
      );
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('en', 'GB')],
        ),
        'en',
      );
    });

    test('unsupported device locale falls back to en', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [Locale('de', 'DE')],
        ),
        'en',
      );
    });

    test('first supported entry in the device preference list wins', () {
      expect(
        AppState.resolveInitialLanguageCode(
          deviceLocales: const [
            Locale('de', 'DE'),
            Locale('ja', 'JP'),
            Locale('tr', 'TR'),
            Locale('ru', 'RU'),
          ],
        ),
        'tr',
      );
    });

    test('empty device locale list falls back to en', () {
      expect(AppState.resolveInitialLanguageCode(), 'en');
    });
  });

  group('saved preference precedence', () {
    test('saved locale overrides a different supported device locale', () {
      expect(
        AppState.resolveInitialLanguageCode(
          savedValue: 'ru',
          deviceLocales: const [Locale('tr', 'TR')],
        ),
        'ru',
      );
    });

    for (final code in AppState.supportedLanguageCodes) {
      test('saved "$code" restores correctly', () {
        expect(
          AppState.resolveInitialLanguageCode(
            savedValue: code,
            deviceLocales: const [Locale('de', 'DE')],
          ),
          code,
        );
      });
    }

    test('saved regional variants normalize to the base language', () {
      expect(AppState.resolveInitialLanguageCode(savedValue: 'tr_TR'), 'tr');
      expect(AppState.resolveInitialLanguageCode(savedValue: 'fa-IR'), 'fa');
      expect(AppState.resolveInitialLanguageCode(savedValue: 'en_US'), 'en');
      expect(AppState.resolveInitialLanguageCode(savedValue: 'ru_RU'), 'ru');
    });
  });

  group('malformed / unsupported saved values', () {
    test('invalid saved value falls back to the supported device locale', () {
      expect(
        AppState.resolveInitialLanguageCode(
          savedValue: 'klingon',
          deviceLocales: const [Locale('tr', 'TR')],
        ),
        'tr',
      );
    });

    test(
      'invalid saved value + unsupported device locale falls back to en',
      () {
        expect(
          AppState.resolveInitialLanguageCode(
            savedValue: 'klingon',
            deviceLocales: const [Locale('de', 'DE')],
          ),
          'en',
        );
      },
    );

    test('empty, whitespace, non-String and null values are ignored', () {
      for (final bad in <Object?>[
        null,
        '',
        '   ',
        42,
        <String>['tr'],
        true,
      ]) {
        expect(
          AppState.resolveInitialLanguageCode(
            savedValue: bad,
            deviceLocales: const [Locale('ru', 'RU')],
          ),
          'ru',
          reason: 'invalid value $bad must not be adopted',
        );
      }
    });

    test('normalizeLanguageCode returns null for unsupported input', () {
      expect(AppState.normalizeLanguageCode('de'), isNull);
      expect(AppState.normalizeLanguageCode(''), isNull);
      expect(AppState.normalizeLanguageCode(null), isNull);
      expect(AppState.normalizeLanguageCode('TR'), 'tr');
      expect(AppState.normalizeLanguageCode('  Fa-IR '), 'fa');
    });
  });

  group('persistence through the canonical path', () {
    test('explicit language change persists under the canonical key', () async {
      final appState = buildAppState();

      await appState.setLocale('tr');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppState.localePreferenceKey), 'tr');
      expect(appState.locale.languageCode, 'tr');
    });

    test(
      'canonical key stays "language" for released-version compatibility',
      () {
        // Renaming this key would strand choices saved by older builds.
        expect(AppState.localePreferenceKey, 'language');
      },
    );

    test('a preference saved by an older version is honoured', () async {
      // Exactly what the previous WelcomePage code wrote.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'language': 'fa',
      });

      final code = await AppState.loadInitialLanguageCode(
        deviceLocales: const [Locale('en', 'US')],
      );

      expect(code, 'fa');
    });

    test('restart simulation restores the last explicit selection', () async {
      final first = buildAppState();
      await first.setLocale('ru');

      // Simulate relaunch: same preference store, fresh resolution + AppState.
      final restoredCode = await AppState.loadInitialLanguageCode(
        deviceLocales: const [Locale('tr', 'TR')],
      );
      final second = buildAppState(initialLanguageCode: restoredCode);

      expect(restoredCode, 'ru');
      expect(second.locale.languageCode, 'ru');
    });

    test(
      'setLocale ignores an unsupported code and does not persist',
      () async {
        final appState = buildAppState(initialLanguageCode: 'tr');

        await appState.setLocale('de');

        final prefs = await SharedPreferences.getInstance();
        expect(appState.locale.languageCode, 'tr', reason: 'unchanged');
        expect(prefs.getString(AppState.localePreferenceKey), isNull);
      },
    );

    test('startup resolution never writes a preference', () async {
      await AppState.loadInitialLanguageCode(
        deviceLocales: const [Locale('tr', 'TR')],
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppState.localePreferenceKey),
        isNull,
        reason: 'initialization is not an explicit user choice',
      );
    });

    test('explicit change notifies listeners', () async {
      final appState = buildAppState();
      var notifications = 0;
      appState.addListener(() => notifications++);

      await appState.setLocale('tr');

      expect(notifications, greaterThan(0));
    });
  });

  group('constructor initialization', () {
    test('applies a supported initial language', () {
      expect(
        buildAppState(initialLanguageCode: 'tr').locale.languageCode,
        'tr',
      );
    });

    test('falls back to en for absent or invalid initial language', () {
      expect(buildAppState().locale.languageCode, 'en');
      expect(
        buildAppState(initialLanguageCode: 'klingon').locale.languageCode,
        'en',
      );
    });
  });

  group('application-level wiring', () {
    // Mirrors main.dart's MaterialApp wiring (context.select on AppState.locale
    // plus the generated delegates) without booting the real app.
    Widget harness(AppState appState) {
      return ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: Builder(
          builder: (context) {
            final locale = context.select<AppState, Locale>((s) => s.locale);
            return MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Text(
                  Localizations.localeOf(context).languageCode,
                  textDirection: Directionality.of(context),
                ),
              ),
            );
          },
        ),
      );
    }

    testWidgets('explicit change rebuilds MaterialApp with the new locale', (
      tester,
    ) async {
      final appState = buildAppState();
      await tester.pumpWidget(harness(appState));
      await tester.pumpAndSettle();

      expect(find.text('en'), findsOneWidget);

      await appState.setLocale('tr');
      await tester.pumpAndSettle();

      expect(find.text('tr'), findsOneWidget);
      expect(find.text('en'), findsNothing);
    });

    testWidgets('Persian selection produces RTL directionality', (
      tester,
    ) async {
      final appState = buildAppState();
      await tester.pumpWidget(harness(appState));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('en'))),
        TextDirection.ltr,
      );

      await appState.setLocale('fa');
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('fa'))),
        TextDirection.rtl,
      );
    });

    testWidgets('Turkish selection stays LTR', (tester) async {
      final appState = buildAppState();
      await tester.pumpWidget(harness(appState));
      await tester.pumpAndSettle();

      await appState.setLocale('tr');
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('tr'))),
        TextDirection.ltr,
      );
    });
  });

  group('supported locale set', () {
    test('AppState codes match AppLocalizations.supportedLocales exactly', () {
      final generated = AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet();

      expect(generated, AppState.supportedLanguageCodes.toSet());
      expect(generated, <String>{'en', 'fa', 'ru', 'tr'});
    });
  });

  group('canonical-path source guards', () {
    // The language selectors must not reintroduce their own persistence.
    // Behaviour is covered above; these pin the single-writer invariant.
    String sourceOf(String path) => File(path).readAsStringSync();

    test('WelcomePage no longer reads or writes the language key', () {
      final source = sourceOf('lib/welcome_page.dart');

      expect(source.contains("getString('language')"), isFalse);
      expect(source.contains("setString('language')"), isFalse);
      expect(source.contains('setLocale('), isTrue);
    });

    test('UserProfilePage has no direct language persistence', () {
      final source = sourceOf('lib/user_profile_page.dart');

      expect(source.contains("getString('language')"), isFalse);
      expect(source.contains("setString('language')"), isFalse);
      expect(source.contains('setLocale('), isTrue);
    });

    test('AppState is the only writer of the language key', () {
      final writers = <String>[];
      final libDir = Directory('lib');

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains("setString(localePreferenceKey") ||
            source.contains("setString('language'")) {
          writers.add(entity.path);
        }
      }

      expect(writers, <String>['lib/app_state.dart']);
    });
  });
}
