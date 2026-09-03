import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/business_draft.dart';
import 'package:barky_matches_fixed/ui/business/petshop/pet_shop_details_page.dart';

/// Brands was mandatory and Working Hours accepted free text, so a seller
/// could not submit without inventing a brand list and could store
/// `10:00_21:00`.
void main() {
  BusinessDraft emptyDraft() => const BusinessDraft(
    sectors: <String>[],
    profile: BusinessProfileDraft(displayName: 'Shop', description: ''),
    contact: BusinessContactDraft(
      phone: '',
      whatsapp: '',
      email: '',
      instagram: '',
      website: '',
      city: '',
      district: '',
      addressLine: '',
    ),
    legal: BusinessLegalDraft(
      taxNumber: '',
      mersisNumber: '',
      companyType: null,
      disclaimerAccepted: true,
      disclaimerVersion: 'v1.0',
      disclaimerAcceptedAt: '',
    ),
    sectorData: <String, dynamic>{},
  );

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PetShopDetailsPage(baseDraft: emptyDraft()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The form is a lazy `ListView`, so no single frame contains every field.
  /// Scroll from top to bottom in steps, collecting each field's validator and
  /// hint keyed by its decoration label.
  Future<Map<String, ({String? Function(String?)? validator, String? hint})>>
  collectFields(WidgetTester tester) async {
    final collected =
        <String, ({String? Function(String?)? validator, String? hint})>{};

    void capture() {
      for (final element in find.byType(TextFormField).evaluate()) {
        final formField = element.widget as TextFormField;
        final textFields = find
            .descendant(
              of: find.byWidget(formField),
              matching: find.byType(TextField),
            )
            .evaluate();
        if (textFields.isEmpty) continue;
        final decoration = (textFields.first.widget as TextField).decoration;
        final label = decoration?.labelText;
        if (label == null) continue;
        collected[label] = (
          validator: formField.validator,
          hint: decoration?.hintText,
        );
      }
    }

    capture();
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(scrollable, const Offset(0, -220));
      await tester.pumpAndSettle();
      capture();
    }
    return collected;
  }

  testWidgets(
    'Brands is labelled optional and Working Hours shows the example',
    (tester) async {
      await pumpForm(tester);
      final fields = await collectFields(tester);

      expect(
        fields.containsKey('Brands (optional)'),
        isTrue,
        reason: 'Brands must be labelled optional',
      );
      expect(
        fields['Working Hours']?.hint,
        'Example: 10:00–21:00',
        reason: 'the working-hours example must be visible',
      );
      // The old hard-coded, unlocalized "Brands" label is gone.
      expect(fields.containsKey('Brands'), isFalse);
    },
  );

  testWidgets('empty Brands does not block validation', (tester) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);

    expect(
      fields['Brands (optional)']!.validator?.call(''),
      isNull,
      reason: 'empty Brands must not block submission',
    );
  });

  testWidgets('whitespace-only Brands is accepted and trims to empty', (
    tester,
  ) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);

    expect(fields['Brands (optional)']!.validator?.call('    '), isNull);
    expect('    '.trim(), isEmpty);
  });

  testWidgets('non-empty Brands is accepted', (tester) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);

    expect(
      fields['Brands (optional)']!.validator?.call('  BrandA, BrandB  '),
      isNull,
    );
    expect('  BrandA, BrandB  '.trim(), 'BrandA, BrandB');
  });

  testWidgets('other required fields stay required', (tester) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);

    for (final label in const ['Shop Name', 'Owner Name', 'Description']) {
      expect(fields[label], isNotNull, reason: label);
      expect(fields[label]!.validator?.call(''), 'Required', reason: label);
    }
  });

  testWidgets('Working Hours rejects the reported underscore value', (
    tester,
  ) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);
    final validator = fields['Working Hours']!.validator!;

    expect(validator('10:00_21:00'), isNotNull);
    expect(validator('10:00-21:00'), isNull);
    expect(validator('10:00–21:00'), isNull);
    expect(validator('  10:00 - 21:00 '), isNull);
    expect(validator(''), 'Required');
  });

  testWidgets('Working Hours distinguishes bad format from bad range', (
    tester,
  ) async {
    await pumpForm(tester);
    final fields = await collectFields(tester);
    final validator = fields['Working Hours']!.validator!;

    // Well-formed range, wrong order → range message.
    expect(
      validator('21:00-10:00'),
      'Closing time must be later than opening time.',
    );
    // Not a range at all → format message.
    expect(
      validator('open daily'),
      'Use the format 10:00–21:00 (24-hour, separated by a dash).',
    );
  });
}
