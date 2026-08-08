import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_enums.dart';
import 'package:barky_matches_fixed/promotion/pet_promotion_state.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_engine.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_state.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);
  final engine = const PromotionRankingEngine(maxPromotionLift: 40);

  Map<String, dynamic> projection({
    required PromotionTargetType type,
    required String targetId,
    String campaignId = 'campaign-1',
    num weight = 10,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) => {
    'campaignId': campaignId,
    'targetType': type.value,
    'targetId': targetId,
    'startsAt': Timestamp.fromDate(
      startsAt ?? now.subtract(const Duration(hours: 1)),
    ),
    'expiresAt': Timestamp.fromDate(
      expiresAt ?? now.add(const Duration(hours: 1)),
    ),
    'rankingWeight': weight,
  };

  PromotionRankingState stateFor(
    String targetId, {
    Iterable<Map<String, dynamic>> projections = const [],
  }) => PromotionRankingState.resolve(
    targetType: PromotionTargetType.pet,
    targetId: targetId,
    projections: projections,
    now: now,
  );

  test('organic targets receive no promotion lift', () {
    final state = stateFor('organic');
    final ranked = engine.rank([
      PromotionRankingInput<String>(
        item: 'organic',
        targetType: PromotionTargetType.pet,
        targetId: 'organic',
        organicScore: 20,
        promotionState: state,
      ),
    ]);
    expect(ranked.single.score, 20);
    expect(ranked.single.promotionState.source, PromotionRankingSource.organic);
  });

  test(
    'active promotion receives bounded lift and expired/future states do not',
    () {
      final active = stateFor(
        'active',
        projections: [
          projection(
            type: PromotionTargetType.pet,
            targetId: 'active',
            weight: 999,
          ),
        ],
      );
      final expired = stateFor(
        'expired',
        projections: [
          projection(
            type: PromotionTargetType.pet,
            targetId: 'expired',
            expiresAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      final future = stateFor(
        'future',
        projections: [
          projection(
            type: PromotionTargetType.pet,
            targetId: 'future',
            startsAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      );
      expect(
        engine.score(
          PromotionRankingInput<String>(
            item: 'active',
            targetType: PromotionTargetType.pet,
            targetId: 'active',
            organicScore: 20,
            promotionState: active,
          ),
        ),
        60,
      );
      expect(expired.isPromoted, isFalse);
      expect(future.isPromoted, isFalse);
    },
  );

  test('legacy Pet state is fallback-only and never stacks with Promotion', () {
    final pet = PetPromotionState.resolve(
      promotionProjection: projection(
        type: PromotionTargetType.pet,
        targetId: 'dog-1',
        weight: 12,
      ),
      legacyIsSponsored: true,
      legacyBoostScore: 180,
      legacyExpiresAt: Timestamp.fromDate(now.add(const Duration(days: 1))),
      targetId: 'dog-1',
      now: now,
    );
    expect(pet.source, PetPromotionSource.promotion);
    expect(
      engine.score(
        PromotionRankingInput<String>(
          item: 'dog-1',
          targetType: PromotionTargetType.pet,
          targetId: 'dog-1',
          organicScore: 10,
          promotionState: pet.normalized,
        ),
      ),
      22,
    );
  });

  test('multiple valid campaigns select one deterministically', () {
    final state = stateFor(
      'dog-1',
      projections: [
        projection(
          type: PromotionTargetType.pet,
          targetId: 'dog-1',
          campaignId: 'z',
          weight: 10,
        ),
        projection(
          type: PromotionTargetType.pet,
          targetId: 'dog-1',
          campaignId: 'a',
          weight: 10,
        ),
        projection(
          type: PromotionTargetType.pet,
          targetId: 'other',
          campaignId: 'x',
          weight: 100,
        ),
      ],
    );
    expect(state.campaignId, 'a');
    expect(state.targetId, 'dog-1');
  });

  test('organic ordering is stable with deterministic target ID ties', () {
    final ranked = engine.rank([
      PromotionRankingInput<String>(
        item: 'z',
        targetType: PromotionTargetType.pet,
        targetId: 'z',
        organicScore: 5,
        promotionState: stateFor('z'),
      ),
      PromotionRankingInput<String>(
        item: 'a',
        targetType: PromotionTargetType.pet,
        targetId: 'a',
        organicScore: 5,
        promotionState: stateFor('a'),
      ),
    ]);
    expect(ranked.map((entry) => entry.item), ['a', 'z']);
  });

  test(
    'the normalized projection supports every target type without financial data',
    () {
      for (final type in PromotionTargetType.values) {
        final state = PromotionRankingState.fromProjection(
          projection(type: type, targetId: '${type.value}-1'),
          now: now,
        );
        expect(state?.targetType, type);
        expect(state?.isPromoted, isTrue);
        expect(state?.rankingWeight, 10);
        expect(state!.toString(), isNot(contains('price')));
      }
    },
  );

  test('projection target identity mismatch fails closed', () {
    final state = stateFor(
      'dog-1',
      projections: [
        projection(type: PromotionTargetType.pet, targetId: 'dog-2'),
      ],
    );
    expect(state.isPromoted, isFalse);
  });
}
