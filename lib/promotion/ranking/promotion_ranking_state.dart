import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/promotion_enums.dart';

enum PromotionRankingSource { organic, promotionEngine, legacyCompatibility }

/// Public/query-facing promotion state used by ranking surfaces.
///
/// It deliberately contains no price, payment, provider, or campaign
/// financial payload. Projection timestamps are revalidated at read time.
class PromotionRankingState {
  const PromotionRankingState({
    required this.targetType,
    required this.targetId,
    required this.isPromoted,
    required this.rankingWeight,
    required this.source,
    this.campaignId,
    this.startsAt,
    this.expiresAt,
  });

  factory PromotionRankingState.organic({
    required PromotionTargetType targetType,
    required String targetId,
  }) => PromotionRankingState(
    targetType: targetType,
    targetId: targetId,
    isPromoted: false,
    rankingWeight: 0,
    source: PromotionRankingSource.organic,
  );

  final PromotionTargetType targetType;
  final String targetId;
  final bool isPromoted;
  final double rankingWeight;
  final PromotionRankingSource source;
  final String? campaignId;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  bool isEligibleAt(DateTime now) =>
      isPromoted &&
      (startsAt == null || !now.isBefore(startsAt!)) &&
      expiresAt != null &&
      now.isBefore(expiresAt!);

  /// Resolves multiple projections without stacking them. The valid
  /// highest-weight projection wins, with campaign ID as a stable tie-breaker.
  static PromotionRankingState resolve({
    required PromotionTargetType targetType,
    required String targetId,
    Iterable<Map<String, dynamic>> projections = const [],
    PromotionRankingState? legacyFallback,
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final valid =
        projections
            .map((projection) => fromProjection(projection, now: referenceTime))
            .whereType<PromotionRankingState>()
            .where(
              (state) =>
                  state.targetType == targetType && state.targetId == targetId,
            )
            .toList()
          ..sort((a, b) {
            final weight = b.rankingWeight.compareTo(a.rankingWeight);
            if (weight != 0) return weight;
            return (a.campaignId ?? '').compareTo(b.campaignId ?? '');
          });

    if (valid.isNotEmpty) return valid.first;
    if (legacyFallback != null && legacyFallback.isEligibleAt(referenceTime)) {
      return legacyFallback;
    }
    return PromotionRankingState.organic(
      targetType: targetType,
      targetId: targetId,
    );
  }

  static PromotionRankingState? fromProjection(
    Map<String, dynamic> projection, {
    DateTime? now,
  }) {
    final targetType = _targetType(projection['targetType']);
    final targetId = projection['targetId']?.toString();
    final startsAt = _asDateTime(projection['startsAt']);
    final expiresAt = _asDateTime(projection['expiresAt']);
    final referenceTime = now ?? DateTime.now();
    if (targetType == null || targetId == null || targetId.isEmpty) return null;
    if (startsAt == null || expiresAt == null) return null;
    if (expiresAt.isBefore(startsAt) ||
        !referenceTime.isBefore(expiresAt) ||
        referenceTime.isBefore(startsAt)) {
      return null;
    }
    final weight = projection['rankingWeight'];
    if (weight is! num || weight < 0) return null;
    return PromotionRankingState(
      targetType: targetType,
      targetId: targetId,
      isPromoted: true,
      rankingWeight: weight.toDouble(),
      source: PromotionRankingSource.promotionEngine,
      campaignId: projection['campaignId']?.toString(),
      startsAt: startsAt,
      expiresAt: expiresAt,
    );
  }

  static PromotionTargetType? _targetType(Object? value) {
    try {
      return PromotionTargetType.fromValue(value);
    } on FormatException {
      return null;
    }
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
