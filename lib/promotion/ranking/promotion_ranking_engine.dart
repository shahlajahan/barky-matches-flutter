import '../models/promotion_enums.dart';
import 'promotion_ranking_state.dart';

class PromotionRankingInput<T> {
  const PromotionRankingInput({
    required this.item,
    required this.targetType,
    required this.targetId,
    required this.organicScore,
    required this.promotionState,
    this.ownerId,
    this.businessId,
  });

  final T item;
  final PromotionTargetType targetType;
  final String targetId;
  final num organicScore;
  final PromotionRankingState promotionState;
  final String? ownerId;
  final String? businessId;
}

class PromotionRankedItem<T> {
  const PromotionRankedItem({
    required this.item,
    required this.targetId,
    required this.score,
    required this.promotionState,
  });

  final T item;
  final String targetId;
  final double score;
  final PromotionRankingState promotionState;
}

/// V1 ranking policy: organic relevance plus a bounded, deterministic lift.
/// It is intentionally not an auction, bid, price, or quality model.
class PromotionRankingEngine {
  const PromotionRankingEngine({this.maxPromotionLift = 40});

  final double maxPromotionLift;

  double score<T>(PromotionRankingInput<T> input) {
    final lift = input.promotionState.isPromoted
        ? input.promotionState.rankingWeight.clamp(0, maxPromotionLift)
        : 0;
    return input.organicScore.toDouble() + lift;
  }

  List<PromotionRankedItem<T>> rank<T>(
    Iterable<PromotionRankingInput<T>> inputs,
  ) {
    final ranked = inputs
        .map(
          (input) => PromotionRankedItem(
            item: input.item,
            targetId: input.targetId,
            score: score(input),
            promotionState: input.promotionState,
          ),
        )
        .toList();
    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      return a.targetId.compareTo(b.targetId);
    });
    return ranked;
  }
}
