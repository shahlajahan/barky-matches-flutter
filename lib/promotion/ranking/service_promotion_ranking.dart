import '../models/promotion_enums.dart';
import '../models/promotion_service_sector.dart';
import 'promotion_ranking_engine.dart';
import 'promotion_ranking_state.dart';

/// Adapts real service records into the target-agnostic M5 ranking engine.
/// Network access and projection loading stay outside this pure adapter.
class ServicePromotionRanking {
  const ServicePromotionRanking._();

  static List<Map<String, dynamic>> rank({
    required String businessId,
    required PromotionServiceSector sector,
    required List<Map<String, dynamic>> services,
    Map<String, List<Map<String, dynamic>>> projectionsByTargetId = const {},
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final inputs = <PromotionRankingInput<Map<String, dynamic>>>[];
    for (var index = 0; index < services.length; index++) {
      final service = services[index];
      final serviceId =
          (service['id'] ?? service['serviceId'])?.toString().trim() ?? '';
      if (serviceId.isEmpty) continue;
      final targetId = PromotionServiceTargetId(
        sector: sector,
        businessId: businessId,
        serviceId: serviceId,
      ).value;
      final eligible =
          service['isActive'] != false &&
          service['isHidden'] != true &&
          service['isBookable'] != false &&
          service['available'] != false;
      inputs.add(
        PromotionRankingInput(
          item: service,
          targetType: PromotionTargetType.service,
          targetId: targetId,
          organicScore: services.length - index,
          businessId: businessId,
          promotionState: eligible
              ? PromotionRankingState.resolve(
                  targetType: PromotionTargetType.service,
                  targetId: targetId,
                  projections: projectionsByTargetId[targetId] ?? const [],
                  now: referenceTime,
                )
              : PromotionRankingState.organic(
                  targetType: PromotionTargetType.service,
                  targetId: targetId,
                ),
        ),
      );
    }
    return const PromotionRankingEngine()
        .rank(inputs)
        .map((ranked) => ranked.item)
        .toList();
  }
}
