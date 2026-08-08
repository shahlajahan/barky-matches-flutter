import 'package:cloud_firestore/cloud_firestore.dart';

import 'promotion_enums.dart';
import 'promotion_plan.dart';
import 'promotion_target.dart';

class PromotionCampaign {
  const PromotionCampaign({
    required this.campaignId,
    required this.targetType,
    required this.targetId,
    required this.ownerUid,
    required this.pricingModel,
    required this.planId,
    required this.pricingVersion,
    required this.durationHours,
    required this.currency,
    required this.price,
    required this.status,
    this.businessId,
    this.sector,
    this.paymentProvider,
    this.paymentAttemptId,
    this.paymentId,
    this.providerOrderId,
    this.providerTransactionId,
    this.paymentStatus,
    this.failureCode,
    this.idempotencyKey,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.verifiedAt,
    this.activatedAt,
    this.startsAt,
    this.expiresAt,
    this.cancelledAt,
    this.expiredAt,
    this.refundedAt,
    this.rankingWeight,
    this.placementPolicy,
    this.version = 1,
  }) : assert(campaignId != ''),
       assert(targetId != ''),
       assert(ownerUid != '');

  final String campaignId;
  final PromotionTargetType targetType;
  final String targetId;
  final String ownerUid;
  final String? businessId;
  final String? sector;
  final PromotionPricingModel pricingModel;
  final String planId;
  final int pricingVersion;
  final int durationHours;
  final String currency;
  final double price;
  final PromotionCampaignStatus status;
  final String? paymentProvider;
  final String? paymentAttemptId;
  final String? paymentId;
  final String? providerOrderId;
  final String? providerTransactionId;
  final String? paymentStatus;
  final String? failureCode;
  final String? idempotencyKey;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? paidAt;
  final Timestamp? verifiedAt;
  final Timestamp? activatedAt;
  final Timestamp? startsAt;
  final Timestamp? expiresAt;
  final Timestamp? cancelledAt;
  final Timestamp? expiredAt;
  final Timestamp? refundedAt;
  final double? rankingWeight;
  final String? placementPolicy;
  final int version;

  factory PromotionCampaign.fromJson(
    String campaignId,
    Map<String, dynamic> json,
  ) {
    final price = _requiredNum(json, 'price').toDouble();
    final durationHours = _requiredInt(json, 'durationHours');
    final pricingVersion = _requiredInt(json, 'pricingVersion');
    if (price < 0 || durationHours <= 0 || pricingVersion <= 0) {
      throw const FormatException(
        'Promotion campaign has invalid commercial terms',
      );
    }
    final target = PromotionTarget.fromJson(json);
    return PromotionCampaign(
      campaignId: campaignId,
      targetType: target.targetType,
      targetId: target.targetId,
      ownerUid: target.ownerUid,
      businessId: target.businessId,
      sector: target.sector,
      pricingModel: PromotionPricingModel.fromValue(json['pricingModel']),
      planId: _requiredString(json, 'planId'),
      pricingVersion: pricingVersion,
      durationHours: durationHours,
      currency: _requiredString(json, 'currency'),
      price: price,
      status: PromotionCampaignStatus.fromValue(json['status']),
      paymentProvider: json['paymentProvider'] as String?,
      paymentAttemptId: json['paymentAttemptId'] as String?,
      paymentId: json['paymentId'] as String?,
      providerOrderId: json['providerOrderId'] as String?,
      providerTransactionId: json['providerTransactionId'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      failureCode: json['failureCode'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
      createdAt: _asTimestamp(json['createdAt']),
      updatedAt: _asTimestamp(json['updatedAt']),
      paidAt: _asTimestamp(json['paidAt']),
      verifiedAt: _asTimestamp(json['verifiedAt']),
      activatedAt: _asTimestamp(json['activatedAt']),
      startsAt: _asTimestamp(json['startsAt']),
      expiresAt: _asTimestamp(json['expiresAt']),
      cancelledAt: _asTimestamp(json['cancelledAt']),
      expiredAt: _asTimestamp(json['expiredAt']),
      refundedAt: _asTimestamp(json['refundedAt']),
      rankingWeight: (json['rankingWeight'] as num?)?.toDouble(),
      placementPolicy: json['placementPolicy'] as String?,
      version: _requiredInt(json, 'version'),
    );
  }

  factory PromotionCampaign.draftFromPlan({
    required String campaignId,
    required PromotionTarget target,
    required PromotionPlan plan,
    required Timestamp createdAt,
  }) {
    if (plan.targetType != target.targetType) {
      throw const FormatException(
        'Promotion plan target type does not match target',
      );
    }
    return PromotionCampaign(
      campaignId: campaignId,
      targetType: target.targetType,
      targetId: target.targetId,
      ownerUid: target.ownerUid,
      businessId: target.businessId,
      sector: target.sector,
      pricingModel: plan.pricingModel,
      planId: plan.planId,
      pricingVersion: plan.pricingVersion,
      durationHours: plan.durationHours,
      currency: plan.currency,
      price: plan.price,
      status: PromotionCampaignStatus.draft,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  bool isEligibleAt(DateTime now) => isPromotionEligibleAt(
    status: status,
    now: now,
    startsAt: startsAt?.toDate(),
    expiresAt: expiresAt?.toDate(),
  );

  PromotionCampaign transitionTo(
    PromotionCampaignStatus nextStatus, {
    Timestamp? updatedAt,
  }) {
    if (!isAllowedPromotionCampaignTransition(status, nextStatus)) {
      throw StateError(
        'Invalid promotion campaign transition: ${status.value} -> ${nextStatus.value}',
      );
    }
    return _copyWith(
      status: nextStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'campaignId': campaignId,
    'targetType': targetType.value,
    'targetId': targetId,
    'ownerUid': ownerUid,
    if (businessId != null) 'businessId': businessId,
    if (sector != null) 'sector': sector,
    'pricingModel': pricingModel.value,
    'planId': planId,
    'pricingVersion': pricingVersion,
    'durationHours': durationHours,
    'currency': currency,
    'price': price,
    'status': status.value,
    if (paymentProvider != null) 'paymentProvider': paymentProvider,
    if (paymentAttemptId != null) 'paymentAttemptId': paymentAttemptId,
    if (paymentId != null) 'paymentId': paymentId,
    if (providerOrderId != null) 'providerOrderId': providerOrderId,
    if (providerTransactionId != null)
      'providerTransactionId': providerTransactionId,
    if (paymentStatus != null) 'paymentStatus': paymentStatus,
    if (failureCode != null) 'failureCode': failureCode,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (paidAt != null) 'paidAt': paidAt,
    if (verifiedAt != null) 'verifiedAt': verifiedAt,
    if (activatedAt != null) 'activatedAt': activatedAt,
    if (startsAt != null) 'startsAt': startsAt,
    if (expiresAt != null) 'expiresAt': expiresAt,
    if (cancelledAt != null) 'cancelledAt': cancelledAt,
    if (expiredAt != null) 'expiredAt': expiredAt,
    if (refundedAt != null) 'refundedAt': refundedAt,
    if (rankingWeight != null) 'rankingWeight': rankingWeight,
    if (placementPolicy != null) 'placementPolicy': placementPolicy,
    'version': version,
  };

  PromotionCampaign _copyWith({
    required PromotionCampaignStatus status,
    required Timestamp? updatedAt,
  }) {
    return PromotionCampaign(
      campaignId: campaignId,
      targetType: targetType,
      targetId: targetId,
      ownerUid: ownerUid,
      businessId: businessId,
      sector: sector,
      pricingModel: pricingModel,
      planId: planId,
      pricingVersion: pricingVersion,
      durationHours: durationHours,
      currency: currency,
      price: price,
      status: status,
      paymentProvider: paymentProvider,
      paymentAttemptId: paymentAttemptId,
      paymentId: paymentId,
      providerOrderId: providerOrderId,
      providerTransactionId: providerTransactionId,
      paymentStatus: paymentStatus,
      failureCode: failureCode,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
      paidAt: paidAt,
      verifiedAt: verifiedAt,
      activatedAt: activatedAt,
      startsAt: startsAt,
      expiresAt: expiresAt,
      cancelledAt: cancelledAt,
      expiredAt: expiredAt,
      refundedAt: refundedAt,
      rankingWeight: rankingWeight,
      placementPolicy: placementPolicy,
      version: version,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Promotion campaign $key is required');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || value % 1 != 0) {
      throw FormatException('Promotion campaign $key must be an integer');
    }
    return value.toInt();
  }

  static num _requiredNum(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('Promotion campaign $key must be numeric');
    }
    return value;
  }

  static Timestamp? _asTimestamp(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    throw const FormatException('Promotion campaign timestamp is invalid');
  }
}
