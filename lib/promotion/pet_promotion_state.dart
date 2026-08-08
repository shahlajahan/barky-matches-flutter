import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/promotion_enums.dart';
import 'ranking/promotion_ranking_state.dart';

/// Pet-specific compatibility adapter over the target-agnostic ranking state.
class PetPromotionState {
  const PetPromotionState(this.normalized);

  final PromotionRankingState normalized;

  bool get isActive => normalized.isPromoted;
  double get rankingWeight => normalized.rankingWeight;
  PetPromotionSource get source => switch (normalized.source) {
    PromotionRankingSource.promotionEngine => PetPromotionSource.promotion,
    PromotionRankingSource.legacyCompatibility => PetPromotionSource.legacy,
    PromotionRankingSource.organic => PetPromotionSource.none,
  };
  DateTime? get expiresAt => normalized.expiresAt;

  factory PetPromotionState.resolve({
    required Map<String, dynamic>? promotionProjection,
    Iterable<Map<String, dynamic>>? promotionProjections,
    required bool legacyIsSponsored,
    required num legacyBoostScore,
    required Object? legacyExpiresAt,
    String? targetId,
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final legacyExpiry = _asDateTime(legacyExpiresAt);
    final legacy =
        legacyIsSponsored &&
            legacyExpiry != null &&
            referenceTime.isBefore(legacyExpiry)
        ? PromotionRankingState(
            targetType: PromotionTargetType.pet,
            targetId: targetId ?? '',
            isPromoted: true,
            rankingWeight: legacyBoostScore.toDouble().clamp(
              0,
              double.infinity,
            ),
            source: PromotionRankingSource.legacyCompatibility,
            expiresAt: legacyExpiry,
          )
        : null;
    final projections = [
      if (promotionProjection != null) promotionProjection,
      ...?promotionProjections,
    ];
    return PetPromotionState(
      PromotionRankingState.resolve(
        targetType: PromotionTargetType.pet,
        targetId:
            targetId ?? promotionProjection?['targetId']?.toString() ?? '',
        projections: projections,
        legacyFallback: legacy,
        now: referenceTime,
      ),
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

enum PetPromotionSource { none, legacy, promotion }
