import 'package:cloud_firestore/cloud_firestore.dart';

class SellerShippingConfig {
  final String businessId;

  // 🚚 carriers
  final List<String> activeCarrierCodes;

  // 💰 pricing
  final String pricingModel;
  // fixed | carrier_based | free | conditional

  final double? fixedShippingFee;

  final double? freeShippingThreshold;

  final String shippingPayer;
  // buyer | seller | conditional

  // 📦 limits
  final double? maxDesi;
  final List<String> excludedCities;

  // ⏱ delivery
  final int? preparationDays;
  final int? maxDeliveryDays;

  // 🔁 returns
  final bool allowReturns;
  final int? returnWindowDays;
  final String? returnShippingPayer;

  // timestamps
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  SellerShippingConfig({
    required this.businessId,
    required this.activeCarrierCodes,
    required this.pricingModel,
    required this.shippingPayer,

    this.fixedShippingFee,
    this.freeShippingThreshold,
    this.maxDesi,
    this.excludedCities = const [],
    this.preparationDays,
    this.maxDeliveryDays,
    this.allowReturns = false,
    this.returnWindowDays,
    this.returnShippingPayer,
    this.createdAt,
    this.updatedAt,
  });

  // =========================
  // 🔥 FROM JSON
  // =========================
  factory SellerShippingConfig.fromJson(String id, Map<String, dynamic> json) {
    return SellerShippingConfig(
      businessId: id,
      activeCarrierCodes: List<String>.from(json['activeCarrierCodes'] ?? []),
      pricingModel: json['pricingModel'] ?? 'fixed',
      shippingPayer: json['shippingPayer'] ?? 'buyer',

      fixedShippingFee: (json['fixedShippingFee'] as num?)?.toDouble(),

      freeShippingThreshold: (json['freeShippingThreshold'] as num?)
          ?.toDouble(),

      maxDesi: (json['maxDesi'] as num?)?.toDouble(),

      excludedCities: List<String>.from(json['excludedCities'] ?? []),

      preparationDays: json['preparationDays'],
      maxDeliveryDays: json['maxDeliveryDays'],

      allowReturns: json['allowReturns'] ?? false,
      returnWindowDays: json['returnWindowDays'],
      returnShippingPayer: json['returnShippingPayer'],

      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  // =========================
  // 🔥 TO JSON
  // =========================
  Map<String, dynamic> toJson() {
    return {
      "activeCarrierCodes": activeCarrierCodes,
      "pricingModel": pricingModel,
      "shippingPayer": shippingPayer,

      "fixedShippingFee": fixedShippingFee,
      "freeShippingThreshold": freeShippingThreshold,

      "maxDesi": maxDesi,
      "excludedCities": excludedCities,

      "preparationDays": preparationDays,
      "maxDeliveryDays": maxDeliveryDays,

      "allowReturns": allowReturns,
      "returnWindowDays": returnWindowDays,
      "returnShippingPayer": returnShippingPayer,

      "createdAt": createdAt ?? FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };
  }
}
