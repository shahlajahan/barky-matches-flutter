import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_enums.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_plan.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_engine.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_state.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 10);

  PromotionRankingState active(String id) => PromotionRankingState.resolve(
    targetType: PromotionTargetType.product,
    targetId: id,
    now: now,
    projections: [
      {
        'campaignId': 'campaign-$id',
        'targetType': 'PRODUCT',
        'targetId': id,
        'startsAt': now.subtract(const Duration(minutes: 1)),
        'expiresAt': now.add(const Duration(hours: 24)),
        'rankingWeight': 10,
      },
    ],
  );

  test('PRODUCT plans retain the V1 server values', () {
    final plans = [
      PromotionPlan.fromJson('product_24h_v1', {
        'targetType': 'PRODUCT',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 24,
        'price': 39,
        'currency': 'TRY',
        'pricingVersion': 1,
        'rankingLift': 10,
        'displayOrder': 1,
        'maxConcurrentPerOwner': 3,
        'maxConcurrentPerBusiness': 5,
        'enabled': true,
      }),
      PromotionPlan.fromJson('product_3d_v1', {
        'targetType': 'PRODUCT',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 72,
        'price': 89,
        'currency': 'TRY',
        'pricingVersion': 1,
        'rankingLift': 10,
        'displayOrder': 2,
        'maxConcurrentPerOwner': 3,
        'maxConcurrentPerBusiness': 5,
        'enabled': true,
      }),
      PromotionPlan.fromJson('product_7d_v1', {
        'targetType': 'PRODUCT',
        'pricingModel': 'FIXED_DURATION',
        'durationHours': 168,
        'price': 169,
        'currency': 'TRY',
        'pricingVersion': 1,
        'rankingLift': 10,
        'displayOrder': 3,
        'maxConcurrentPerOwner': 3,
        'maxConcurrentPerBusiness': 5,
        'enabled': true,
      }),
    ];
    expect(plans.map((plan) => plan.durationHours), [24, 72, 168]);
    expect(plans.map((plan) => plan.price), [39, 89, 169]);
    expect(
      plans.every((plan) => plan.targetType == PromotionTargetType.product),
      true,
    );
  });

  test('Product ranking uses the central bounded engine and no stacking', () {
    final organic = PromotionRankingState.organic(
      targetType: PromotionTargetType.product,
      targetId: 'organic',
    );
    final engine = const PromotionRankingEngine();
    final ranked = engine.rank([
      PromotionRankingInput(
        item: 'organic',
        targetType: PromotionTargetType.product,
        targetId: 'organic',
        organicScore: 20,
        promotionState: organic,
      ),
      PromotionRankingInput(
        item: 'promoted',
        targetType: PromotionTargetType.product,
        targetId: 'promoted',
        organicScore: 20,
        promotionState: active('promoted'),
      ),
    ]);
    expect(ranked.first.item, 'promoted');
    expect(ranked.first.score, 30);

    final duplicateProjection = PromotionRankingState.resolve(
      targetType: PromotionTargetType.product,
      targetId: 'promoted',
      now: now,
      projections: [
        {
          'campaignId': 'high',
          'targetType': 'PRODUCT',
          'targetId': 'promoted',
          'startsAt': now.subtract(const Duration(minutes: 1)),
          'expiresAt': now.add(const Duration(hours: 1)),
          'rankingWeight': 100,
        },
        {
          'campaignId': 'low',
          'targetType': 'PRODUCT',
          'targetId': 'promoted',
          'startsAt': now.subtract(const Duration(minutes: 1)),
          'expiresAt': now.add(const Duration(hours: 1)),
          'rankingWeight': 10,
        },
      ],
    );
    expect(duplicateProjection.rankingWeight, 100);
    expect(
      engine.score(
        PromotionRankingInput(
          item: 'promoted',
          targetType: PromotionTargetType.product,
          targetId: 'promoted',
          organicScore: 0,
          promotionState: duplicateProjection,
        ),
      ),
      40,
    );
  });

  test('wrong, expired, and future Product projections stay organic', () {
    final wrongType = PromotionRankingState.resolve(
      targetType: PromotionTargetType.product,
      targetId: 'p',
      now: now,
      projections: [
        {
          'targetType': 'PET',
          'targetId': 'p',
          'startsAt': now,
          'expiresAt': now.add(const Duration(hours: 1)),
          'rankingWeight': 10,
        },
      ],
    );
    final expired = PromotionRankingState.resolve(
      targetType: PromotionTargetType.product,
      targetId: 'p',
      now: now,
      projections: [
        {
          'targetType': 'PRODUCT',
          'targetId': 'p',
          'startsAt': now.subtract(const Duration(hours: 2)),
          'expiresAt': now,
          'rankingWeight': 10,
        },
      ],
    );
    expect(wrongType.isPromoted, false);
    expect(expired.isPromoted, false);
  });
}
