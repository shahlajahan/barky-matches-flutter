import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_enums.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_plan.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_service_sector.dart';
import 'package:barky_matches_fixed/promotion/ranking/service_promotion_ranking.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 10);

  Map<String, dynamic> planJson(int duration, num price) => {
    'targetType': 'SERVICE',
    'pricingModel': 'FIXED_DURATION',
    'durationHours': duration,
    'price': price,
    'currency': 'TRY',
    'rankingLift': 10,
    'enabled': true,
    'pricingVersion': 1,
    'displayOrder': duration,
    'maxConcurrentPerOwner': 3,
    'maxConcurrentPerBusiness': 5,
  };

  test('SERVICE plans retain the 49/119/219 TRY V1 values', () {
    final plans = [
      PromotionPlan.fromJson('service_24h_v1', planJson(24, 49)),
      PromotionPlan.fromJson('service_3d_v1', planJson(72, 119)),
      PromotionPlan.fromJson('service_7d_v1', planJson(168, 219)),
    ];
    expect(plans.map((plan) => plan.price), [49, 119, 219]);
    expect(
      plans.every((plan) => plan.targetType == PromotionTargetType.service),
      true,
    );
  });

  test('SERVICE identity includes sector, business, and service ID', () {
    final vet = PromotionServiceTargetId(
      sector: PromotionServiceSector.vet,
      businessId: 'business-a',
      serviceId: 'abc',
    );
    final groomer = PromotionServiceTargetId(
      sector: PromotionServiceSector.groomer,
      businessId: 'business-a',
      serviceId: 'abc',
    );
    expect(vet.value, 'service/VET/business-a/abc');
    expect(groomer.value, 'service/GROOMER/business-a/abc');
    expect(vet.value, isNot(groomer.value));
    expect(PromotionServiceTargetId.parse(vet.value)?.serviceId, 'abc');
  });

  test(
    'Service ranking uses M5 bounded lift and ignores expired or unavailable services',
    () {
      final ranked = ServicePromotionRanking.rank(
        businessId: 'business-a',
        sector: PromotionServiceSector.vet,
        now: now,
        services: [
          {'id': 'organic', 'isActive': true},
          {'id': 'promoted', 'isActive': true},
          {'id': 'expired', 'isActive': true},
          {'id': 'unavailable', 'isActive': false},
        ],
        projectionsByTargetId: {
          'service/VET/business-a/promoted': [
            {
              'targetType': 'SERVICE',
              'targetId': 'service/VET/business-a/promoted',
              'startsAt': now.subtract(const Duration(minutes: 1)),
              'expiresAt': now.add(const Duration(hours: 1)),
              'rankingWeight': 100,
            },
          ],
          'service/VET/business-a/expired': [
            {
              'targetType': 'SERVICE',
              'targetId': 'service/VET/business-a/expired',
              'startsAt': now.subtract(const Duration(hours: 2)),
              'expiresAt': now,
              'rankingWeight': 100,
            },
          ],
        },
      );
      expect(ranked.first['id'], 'promoted');
      expect(ranked.any((service) => service['id'] == 'unavailable'), true);
      expect(ranked.indexOf(ranked.firstWhere((s) => s['id'] == 'expired')), 2);
    },
  );

  test('Service ranking accepts the canonical serviceId field', () {
    final ranked = ServicePromotionRanking.rank(
      businessId: 'business-a',
      sector: PromotionServiceSector.vet,
      now: now,
      services: [
        {'serviceId': 'laboratory', 'title': 'Laboratory', 'isActive': true},
      ],
    );

    expect(ranked, hasLength(1));
    expect(ranked.single['serviceId'], 'laboratory');
  });

  test('SERVICE remains distinct from BUSINESS and other target types', () {
    final id = PromotionServiceTargetId(
      sector: PromotionServiceSector.groomer,
      businessId: 'same',
      serviceId: 'abc',
    ).value;
    expect(id, isNot('abc'));
    expect(PromotionServiceSector.petHotel.m7Enabled, false);
    expect(PromotionServiceSector.petTaxi.m7Enabled, false);
  });
}
