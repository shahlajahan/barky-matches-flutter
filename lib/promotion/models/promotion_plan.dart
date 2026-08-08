import 'package:cloud_firestore/cloud_firestore.dart';

import 'promotion_enums.dart';

class PromotionPlan {
  const PromotionPlan({
    required this.planId,
    required this.targetType,
    required this.pricingModel,
    required this.durationHours,
    required this.price,
    required this.currency,
    required this.rankingLift,
    required this.enabled,
    required this.pricingVersion,
    required this.displayOrder,
    required this.maxConcurrentPerOwner,
    required this.maxConcurrentPerBusiness,
    this.sector,
    this.createdAt,
    this.updatedAt,
  }) : assert(planId != '');

  final String planId;
  final PromotionTargetType targetType;
  final String? sector;
  final PromotionPricingModel pricingModel;
  final int durationHours;
  final double price;
  final String currency;
  final double rankingLift;
  final bool enabled;
  final int pricingVersion;
  final int displayOrder;
  final int maxConcurrentPerOwner;
  final int maxConcurrentPerBusiness;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PromotionPlan.fromJson(String planId, Map<String, dynamic> json) {
    final durationHours = _requiredInt(json, 'durationHours');
    final price = _requiredNum(json, 'price').toDouble();
    final rankingLift = _requiredNum(json, 'rankingLift').toDouble();
    final currency = _requiredString(json, 'currency');
    final pricingVersion = _requiredInt(json, 'pricingVersion');
    if (durationHours <= 0 ||
        price < 0 ||
        rankingLift < 0 ||
        pricingVersion <= 0) {
      throw const FormatException(
        'Promotion plan contains an invalid numeric value',
      );
    }
    return PromotionPlan(
      planId: planId,
      targetType: PromotionTargetType.fromValue(json['targetType']),
      sector: json['sector'] as String?,
      pricingModel: PromotionPricingModel.fromValue(json['pricingModel']),
      durationHours: durationHours,
      price: price,
      currency: currency,
      rankingLift: rankingLift,
      enabled: _requiredBool(json, 'enabled'),
      pricingVersion: pricingVersion,
      displayOrder: _requiredInt(json, 'displayOrder'),
      maxConcurrentPerOwner: _requiredInt(json, 'maxConcurrentPerOwner'),
      maxConcurrentPerBusiness: _requiredInt(json, 'maxConcurrentPerBusiness'),
      createdAt: _asTimestamp(json['createdAt']),
      updatedAt: _asTimestamp(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'targetType': targetType.value,
    if (sector != null) 'sector': sector,
    'pricingModel': pricingModel.value,
    'durationHours': durationHours,
    'price': price,
    'currency': currency,
    'rankingLift': rankingLift,
    'enabled': enabled,
    'pricingVersion': pricingVersion,
    'displayOrder': displayOrder,
    'maxConcurrentPerOwner': maxConcurrentPerOwner,
    'maxConcurrentPerBusiness': maxConcurrentPerBusiness,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Promotion plan $key is required');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || value % 1 != 0) {
      throw FormatException('Promotion plan $key must be an integer');
    }
    return value.toInt();
  }

  static num _requiredNum(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('Promotion plan $key must be numeric');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('Promotion plan $key must be boolean');
    }
    return value;
  }

  static Timestamp? _asTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    throw const FormatException('Promotion plan timestamp is invalid');
  }
}
