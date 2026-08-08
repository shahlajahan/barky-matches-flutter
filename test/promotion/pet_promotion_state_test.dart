import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/promotion/pet_promotion_state.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_plan.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('server PET plans retain the V1 duration and price mapping', () {
    final plans = [
      PromotionPlan.fromJson('pet_24h_v1', {
        'targetType': 'PET',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 24,
        'price': 29,
        'currency': 'TRY',
        'rankingLift': 10,
        'enabled': true,
        'pricingVersion': 1,
        'displayOrder': 1,
        'maxConcurrentPerOwner': 1,
        'maxConcurrentPerBusiness': 1,
      }),
      PromotionPlan.fromJson('pet_3d_v1', {
        'targetType': 'PET',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 72,
        'price': 69,
        'currency': 'TRY',
        'rankingLift': 10,
        'enabled': true,
        'pricingVersion': 1,
        'displayOrder': 2,
        'maxConcurrentPerOwner': 1,
        'maxConcurrentPerBusiness': 1,
      }),
      PromotionPlan.fromJson('pet_7d_v1', {
        'targetType': 'PET',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 168,
        'price': 129,
        'currency': 'TRY',
        'rankingLift': 10,
        'enabled': true,
        'pricingVersion': 1,
        'displayOrder': 3,
        'maxConcurrentPerOwner': 1,
        'maxConcurrentPerBusiness': 1,
      }),
    ];
    expect(plans.map((plan) => [plan.durationHours, plan.price]), [
      [24, 29],
      [72, 69],
      [168, 129],
    ]);
  });

  Map<String, dynamic> projection({
    DateTime? startsAt,
    DateTime? expiresAt,
    num rankingWeight = 10,
  }) => {
    'targetType': 'PET',
    'targetId': 'dog-1',
    'startsAt': Timestamp.fromDate(
      startsAt ?? now.subtract(const Duration(hours: 1)),
    ),
    'expiresAt': Timestamp.fromDate(
      expiresAt ?? now.add(const Duration(hours: 1)),
    ),
    'rankingWeight': rankingWeight,
  };

  test('Promotion projection takes precedence over a legacy boost', () {
    final state = PetPromotionState.resolve(
      promotionProjection: projection(rankingWeight: 10),
      legacyIsSponsored: true,
      legacyBoostScore: 180,
      legacyExpiresAt: Timestamp.fromDate(now.add(const Duration(days: 2))),
      targetId: 'dog-1',
      now: now,
    );

    expect(state.isActive, isTrue);
    expect(state.source, PetPromotionSource.promotion);
    expect(state.rankingWeight, 10);
  });

  test('valid legacy boost remains the compatibility fallback', () {
    final state = PetPromotionState.resolve(
      promotionProjection: null,
      legacyIsSponsored: true,
      legacyBoostScore: 120,
      legacyExpiresAt: Timestamp.fromDate(now.add(const Duration(hours: 2))),
      targetId: 'dog-1',
      now: now,
    );

    expect(state.isActive, isTrue);
    expect(state.source, PetPromotionSource.legacy);
    expect(state.rankingWeight, 120);
  });

  test('expired Promotion and legacy boosts are inactive', () {
    final state = PetPromotionState.resolve(
      promotionProjection: projection(
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
      legacyIsSponsored: true,
      legacyBoostScore: 80,
      legacyExpiresAt: Timestamp.fromDate(
        now.subtract(const Duration(minutes: 1)),
      ),
      targetId: 'dog-1',
      now: now,
    );

    expect(state.isActive, isFalse);
    expect(state.source, PetPromotionSource.none);
  });

  test('a missing expiry never becomes an active promotion', () {
    final state = PetPromotionState.resolve(
      promotionProjection: {'targetType': 'PET', 'rankingWeight': 10},
      legacyIsSponsored: true,
      legacyBoostScore: 80,
      legacyExpiresAt: null,
      targetId: 'dog-1',
      now: now,
    );
    expect(state.isActive, isFalse);
  });
}
