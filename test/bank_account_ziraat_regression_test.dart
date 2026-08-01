// Regression test for the reported production bug: payment.bankName =
// "ziraat" in Firestore, but the Bank Name dropdown showed empty on reopen.
// Exercises the REAL BankAccountSettingsPage widget (not a re-implementation
// of its logic) against a FakeFirebaseFirestore instance seeded with the
// exact reported data shape.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/settings/bank_account_settings_page.dart';

void main() {
  testWidgets(
    'reopening the page with payment.bankName="ziraat" auto-selects '
    '"Ziraat Bankası" in the dropdown',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('businesses').doc('biz-1').set({
        'payment': {
          'accountHolder': 'Koray Test',
          'bankName': 'ziraat',
          'iban': 'TR930001002422870318335002',
          'billingInfo': '',
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BankAccountSettingsPage(
            businessId: 'biz-1',
            firestore: firestore,
          ),
        ),
      );

      // Let the async _load() (Firestore read + setState calls) complete.
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        dropdownFinder,
      );
      // ignore: avoid_print
      print(
        '[test] DropdownButtonFormField.initialValue = '
        '"${dropdown.initialValue}"',
      );
      expect(dropdown.initialValue, 'Ziraat Bankası');

      // And it must actually be visible on screen, not just set internally.
      expect(find.text('Ziraat Bankası'), findsOneWidget);
    },
  );
}
