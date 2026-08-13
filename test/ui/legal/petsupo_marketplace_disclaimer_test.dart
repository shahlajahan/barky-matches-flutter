import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/legal/petsupo_marketplace_disclaimer.dart';

Widget testApp({required VoidCallback onContinue}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            if (await showPetSupoMarketplaceDisclaimer(context)) {
              onContinue();
            }
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cancel closes without continuing', (tester) async {
    var continued = false;
    await tester.pumpWidget(testApp(onContinue: () => continued = true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Before you continue'), findsOneWidget);
    expect(find.text('Accept & Continue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('independent businesses'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(continued, isFalse);
    expect(find.text('Before you continue'), findsNothing);
  });

  testWidgets('accept continues exactly once', (tester) async {
    var continueCount = 0;
    await tester.pumpWidget(testApp(onContinue: () => continueCount++));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept & Continue'));
    await tester.pumpAndSettle();

    expect(continueCount, 1);
  });

  testWidgets('supports the Turkish localized copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPetSupoMarketplaceDisclaimer(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Devam etmeden önce'), findsOneWidget);
    expect(find.text('Kabul Et ve Devam Et'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
  });
}
