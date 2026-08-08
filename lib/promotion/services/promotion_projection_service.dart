import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/promotion_enums.dart';

class PromotionProjectionService {
  PromotionProjectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, List<Map<String, dynamic>>>> readByTargetType(
    PromotionTargetType targetType,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('promotion_active')
          .where('targetType', isEqualTo: targetType.value)
          .get();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final targetId = data['targetId']?.toString().trim();
        if (targetId == null || targetId.isEmpty) continue;
        grouped.putIfAbsent(targetId, () => <Map<String, dynamic>>[]).add(data);
      }
      return grouped;
    } catch (_) {
      // Ranking must fail closed to organic results when projections are unavailable.
      return <String, List<Map<String, dynamic>>>{};
    }
  }
}
