import 'promotion_enums.dart';

class PromotionTarget {
  const PromotionTarget({
    required this.targetType,
    required this.targetId,
    required this.ownerUid,
    this.businessId,
    this.sector,
  }) : assert(targetId != ''),
       assert(ownerUid != '');

  final PromotionTargetType targetType;
  final String targetId;
  final String ownerUid;
  final String? businessId;
  final String? sector;

  factory PromotionTarget.fromJson(Map<String, dynamic> json) {
    final targetId = json['targetId'];
    final ownerUid = json['ownerUid'];
    if (targetId is! String || targetId.trim().isEmpty) {
      throw const FormatException('Promotion targetId is required');
    }
    if (ownerUid is! String || ownerUid.trim().isEmpty) {
      throw const FormatException('Promotion ownerUid is required');
    }
    return PromotionTarget(
      targetType: PromotionTargetType.fromValue(json['targetType']),
      targetId: targetId,
      ownerUid: ownerUid,
      businessId: json['businessId'] as String?,
      sector: json['sector'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'targetType': targetType.value,
    'targetId': targetId,
    'ownerUid': ownerUid,
    if (businessId != null) 'businessId': businessId,
    if (sector != null) 'sector': sector,
  };
}
