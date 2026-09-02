import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/business/company_type_summary_row.dart';

/// Regression coverage for the registration agreement step's company-type
/// summary row, which overflowed to the right on a real iPhone
/// ("RIGHT OVERFLOWED BY ...") when the long localized limited-company
/// label was selected.
///
/// These mount the real production [CompanyTypeSummaryRow] — not a copy —
/// and assert `tester.takeException()` is null after layout, which is how a
/// `RenderFlex` overflow surfaces in a widget test.
void main() {
  /// The real localized strings, copied verbatim from the ARB catalogues so
  /// the test exercises the exact lengths that shipped.
  const labels = <String, String>{
    'en': 'Company Type',
    'tr': 'İşletme Türü',
    'fa': 'نوع شرکت',
    'ru': 'Тип компании',
  };
  const limitedCompanyValues = <String, String>{
    'en': 'Limited Şirket (Limited Company)',
    'tr': 'Limited Şirket',
    'fa': 'شرکت با مسئولیت محدود (Limited Şirket)',
    'ru': 'Limited Şirket (Общество с ограниченной ответственностью)',
  };
  const jointStockValues = <String, String>{
    'en': 'Anonim Şirket (Joint Stock Company)',
    'tr': 'Anonim Şirket',
    'fa': 'شرکت سهامی (Anonim Şirket)',
    'ru': 'Anonim Şirket (Акционерное общество)',
  };

  Future<void> pumpRow(
    WidgetTester tester, {
    required String label,
    required String value,
    required double width,
    required double textScale,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  // Mirrors the registration page's own horizontal padding
                  // so the row is laid out at its real available width.
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CompanyTypeSummaryRow(label: label, value: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 320 is the narrowest iPhone logical width still supported (iPhone SE
  // 1st gen); 390 is the iPhone 14/15 class width the report came from.
  const widths = <String, double>{'narrow': 320, 'iphone': 390};

  for (final width in widths.entries) {
    for (final scale in const [1.0, 1.3]) {
      for (final locale in labels.keys) {
        final direction = locale == 'fa'
            ? TextDirection.rtl
            : TextDirection.ltr;

        testWidgets('limited-company label does not overflow '
            '(${width.key}, scale $scale, $locale)', (tester) async {
          await pumpRow(
            tester,
            label: labels[locale]!,
            value: limitedCompanyValues[locale]!,
            width: width.value,
            textScale: scale,
            direction: direction,
          );

          expect(tester.takeException(), isNull);
          // The value must remain rendered, not clipped away entirely.
          expect(find.text(limitedCompanyValues[locale]!), findsOneWidget);
          expect(find.text(labels[locale]!), findsOneWidget);
        });

        testWidgets('joint-stock label does not overflow '
            '(${width.key}, scale $scale, $locale)', (tester) async {
          await pumpRow(
            tester,
            label: labels[locale]!,
            value: jointStockValues[locale]!,
            width: width.value,
            textScale: scale,
            direction: direction,
          );

          expect(tester.takeException(), isNull);
          expect(find.text(jointStockValues[locale]!), findsOneWidget);
        });
      }
    }
  }

  testWidgets('an extreme value still wraps instead of overflowing', (
    tester,
  ) async {
    await pumpRow(
      tester,
      label: labels['en']!,
      value: 'Limited Şirket ${'(Limited Company) ' * 6}',
      width: 320,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('label and value stay visually distinguishable', (tester) async {
    await pumpRow(
      tester,
      label: labels['en']!,
      value: limitedCompanyValues['en']!,
      width: 390,
      textScale: 1.0,
    );

    final label = tester.widget<Text>(find.text(labels['en']!));
    expect(label.style?.fontWeight, FontWeight.w600);

    final value = tester.widget<Text>(find.text(limitedCompanyValues['en']!));
    expect(value.textAlign, TextAlign.end);
    // The fix must not shrink the value to stay on one line.
    expect(value.style?.fontSize, isNull);
  });
}
