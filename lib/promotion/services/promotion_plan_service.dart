import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/promotion_enums.dart';
import '../models/promotion_plan.dart';

/// Safe client reader for presentation only. Checkout authority remains in
/// the Promotion callable and never uses client-supplied price fields.
class PromotionPlanService {
  PromotionPlanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<PromotionPlan>> readPlans(PromotionTargetType targetType) async {
    final snapshot = await _firestore.collection('promotion_plans').get();
    final plans = <PromotionPlan>[];
    for (final document in snapshot.docs) {
      try {
        final plan = PromotionPlan.fromJson(document.id, document.data());
        if (plan.targetType == targetType &&
            plan.pricingModel == PromotionPricingModel.fixedDuration &&
            plan.enabled &&
            plan.currency.toUpperCase() == 'TRY' &&
            const [24, 72, 168].contains(plan.durationHours)) {
          plans.add(plan);
        }
      } on FormatException {
        // A malformed administrative plan must not break the Pet purchase UI.
      }
    }
    plans.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return plans;
  }

  Future<List<PromotionPlan>> readPetPlans() =>
      readPlans(PromotionTargetType.pet);
}
