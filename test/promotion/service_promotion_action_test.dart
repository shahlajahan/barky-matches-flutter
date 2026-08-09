import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_service_sector.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_campaign_stats.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_plan_service.dart';
import 'package:barky_matches_fixed/promotion/widgets/service_promotion_action.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

Widget _host({
  required PromotionServiceSector sector,
  required bool isActive,
  String price = '100',
  String? activeCampaignId,
  Future<PromotionCampaignStats> Function(String)? loadPerformanceStats,
  PromotionPlanService? planService,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          Text(price),
          ServicePromotionAction(
            businessId: 'business-1',
            serviceId: 'service-1',
            serviceTitle: 'Laboratory',
            sector: sector,
            isActive: isActive,
            activeCampaignId: activeCampaignId,
            loadPerformanceStats: loadPerformanceStats,
            planService: planService,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('active Vet service exposes Boost service', (tester) async {
    await tester.pumpWidget(
      _host(sector: PromotionServiceSector.vet, isActive: true),
    );

    expect(find.text('Boost service'), findsOneWidget);
  });

  testWidgets('inactive Vet service does not expose Boost service', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(sector: PromotionServiceSector.vet, isActive: false),
    );

    expect(find.text('Boost service'), findsNothing);
  });

  testWidgets('Boost service opens the existing PromotionPlanSheet', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('promotion_plans').doc('service_24h_v1').set({
      'targetType': 'SERVICE',
      'pricingModel': 'FIXED_DURATION',
      'durationHours': 24,
      'price': 49,
      'currency': 'TRY',
      'pricingVersion': 1,
      'rankingLift': 40,
      'displayOrder': 1,
      'maxConcurrentPerOwner': 1,
      'maxConcurrentPerBusiness': 1,
      'enabled': true,
    });

    await tester.pumpWidget(
      _host(
        sector: PromotionServiceSector.vet,
        isActive: true,
        planService: PromotionPlanService(firestore: firestore),
      ),
    );

    await tester.tap(find.text('Boost service'));
    await tester.pumpAndSettle();

    expect(find.text('Boost Laboratory'), findsOneWidget);
    expect(
      find.text('Choose a fixed-duration promotion plan.'),
      findsOneWidget,
    );
  });

  testWidgets('active Groomy service exposes the same Boost action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(sector: PromotionServiceSector.groomer, isActive: true),
    );

    expect(find.text('Boost service'), findsOneWidget);
  });

  testWidgets('active campaign opens the existing performance page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        sector: PromotionServiceSector.vet,
        isActive: true,
        activeCampaignId: 'campaign-active',
        loadPerformanceStats: (campaignId) async =>
            PromotionCampaignStats.fromJson({
              'campaignId': campaignId,
              'targetType': 'SERVICE',
              'targetId': 'service/VET/business-1/service-1',
              'impressions': 0,
              'clicks': 0,
              'detailViews': 0,
              'financialMetricsStatus': 'PROVISIONAL',
              'reconciliationStatus': 'PENDING',
            }),
      ),
    );

    expect(find.text('View promotion performance'), findsOneWidget);
    expect(find.text('Boost service'), findsNothing);
    await tester.tap(find.text('View promotion performance'));
    await tester.pumpAndSettle();
    expect(find.text('Promotion performance'), findsNWidgets(2));
  });

  testWidgets('inactive Groomy service does not expose Boost service', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(sector: PromotionServiceSector.groomer, isActive: false),
    );

    expect(find.text('Boost service'), findsNothing);
  });

  test('service action preserves canonical targets and ignores price', () {
    expect(
      ServicePromotionAction.canonicalTargetId(
        sector: PromotionServiceSector.vet,
        businessId: 'business-1',
        serviceId: 'service-1',
      ),
      'service/VET/business-1/service-1',
    );
    expect(
      ServicePromotionAction.canonicalTargetId(
        sector: PromotionServiceSector.groomer,
        businessId: 'business-1',
        serviceId: 'service-1',
      ),
      'service/GROOMER/business-1/service-1',
    );
    expect(
      ServicePromotionAction.isEligible(
        sector: PromotionServiceSector.vet,
        isActive: true,
      ),
      true,
    );
    expect(
      ServicePromotionAction.isEligible(
        sector: PromotionServiceSector.vet,
        isActive: false,
      ),
      false,
    );
    expect(PromotionServiceSector.petHotel.m7Enabled, false);
    expect(PromotionServiceSector.petTaxi.m7Enabled, false);
    expect(
      _host(sector: PromotionServiceSector.vet, isActive: true, price: ''),
      isNotNull,
    );
  });
}
