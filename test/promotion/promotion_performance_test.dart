import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_campaign_stats.dart';
import 'package:barky_matches_fixed/promotion/pages/promotion_performance_page.dart';

PromotionCampaignStats stats({
  String targetType = 'PRODUCT',
  String financialStatus = 'AVAILABLE',
  double? roas = 2.5,
}) => PromotionCampaignStats.fromJson({
  'campaignId': 'campaign-1',
  'targetType': targetType,
  'targetId': targetType == 'PET' ? 'pet-1' : 'product-1',
  'impressions': 10,
  'clicks': 2,
  'detailViews': 1,
  'qualifiedConversions': 0,
  'financialConversions': 0,
  'attributedRevenue': 0,
  'refundedRevenue': 0,
  'netAttributedRevenue': 0,
  'currency': 'TRY',
  'spend': targetType == 'PET' ? 29 : 39,
  'financialMetricsStatus': financialStatus,
  'reconciliationStatus': financialStatus == 'AVAILABLE'
      ? 'CONVERGED'
      : 'PENDING',
  'revenueCapability': targetType == 'PET' ? 'not_applicable' : 'server_attributed',
  'roas': roas,
  'campaignStatus': 'active',
  'durationHours': 24,
});

Widget harness(Future<PromotionCampaignStats> Function(String) loader) =>
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PromotionPerformancePage(
        campaignId: 'campaign-1',
        loadStats: loader,
      ),
    );

void main() {
  test('performance model preserves normalized financial semantics', () {
    final available = stats();
    expect(available.netAttributedRevenue, 0);
    expect(available.financialMetricsStatus, 'AVAILABLE');
    expect(available.roas, 2.5);

    final pet = stats(targetType: 'PET', financialStatus: 'UNAVAILABLE', roas: null);
    expect(pet.hasRevenueAttribution, isFalse);
    expect(pet.roas, isNull);
  });

  testWidgets('PET performance omits financial cards', (tester) async {
    await tester.pumpWidget(harness((_) async => stats(
      targetType: 'PET',
      financialStatus: 'UNAVAILABLE',
      roas: null,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Financial performance'), findsNothing);
    expect(find.text('Financial metrics are not applicable to Pet Boost.'), findsOneWidget);
  });

  testWidgets('Product provisional performance is not shown as final ROAS', (tester) async {
    await tester.pumpWidget(harness((_) async => stats(
      financialStatus: 'PROVISIONAL',
      roas: null,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Financial metrics are still being reconciled.'), findsOneWidget);
    expect(find.text('ROAS'), findsNothing);
  });

  testWidgets('Product available performance renders ROAS', (tester) async {
    await tester.pumpWidget(harness((_) async => stats()));
    await tester.pumpAndSettle();
    expect(find.text('ROAS'), findsOneWidget);
    expect(find.text('2.5x'), findsOneWidget);
  });
}
