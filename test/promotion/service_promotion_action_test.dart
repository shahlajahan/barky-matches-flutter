import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_service_sector.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_plan_service.dart';
import 'package:barky_matches_fixed/promotion/widgets/service_promotion_action.dart';

Widget _host({
  required PromotionServiceSector sector,
  required bool isActive,
  String price = '100',
  PromotionPlanService? planService,
}) {
  return MaterialApp(
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
