import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'seller_shipping_service.dart';
import 'shipping_engine.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/models/seller_shipping_config.dart';

class CheckoutSessionResult {
  final String orderId;
  final String checkoutUrl;
  final String provider;
  final String? token;
final Map<String, dynamic>? pricing; // 🔥 اضافه کن

  const CheckoutSessionResult({
    required this.orderId,
    required this.checkoutUrl,
    required this.provider,
    required this.token,
    this.pricing,
  });

  factory CheckoutSessionResult.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionResult(
      orderId: (json['orderId'] ?? '') as String,
      checkoutUrl: (json['checkoutUrl'] ?? '') as String,
      provider: (json['provider'] ?? 'iyzico') as String,
      token: json['token'] as String?,
pricing: json['pricing'] != null
    ? Map<String, dynamic>.from(json['pricing'])
    : null,
    );
  }
}

class PetshopCheckoutService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west3');

  Future<CheckoutSessionResult> createCheckoutSession({
  required String orderId, // ✅ درست
  required List<Map<String, dynamic>> items,
  required String currency,
  required String successUrl,
  required String cancelUrl,
  required Map<String, dynamic> buyer,
  required Map<String, dynamic> shippingAddress,
  required Map<String, dynamic> billingAddress,
  required String carrier,
  String? note,
}) async {
  try {
    if (items.isEmpty) {
      throw Exception("Cart is empty");
    }

    debugPrint("🟡 createCheckoutSession START");
    debugPrint("🟡 items count = ${items.length}");

    final callable = _functions.httpsCallable(
      'createCheckoutSession',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final payload = {
  "orderId": orderId, // ✅ مهم‌ترین خط
  "note": note,

  "items": items,
  "currency": currency,
  "carrier": carrier,

  "buyer": buyer,
  "shippingAddress": shippingAddress,
  "billingAddress": billingAddress,

  "successUrl": successUrl,
  "cancelUrl": cancelUrl,
};

    debugPrint("🌐 PAYLOAD = $payload");
    debugPrint("🚨 CALLING createCheckoutSession...");

    final response = await callable.call(payload);
debugPrint("✅ RESPONSE RECEIVED");
    final raw = response.data;

    if (raw == null) {
      throw Exception("Checkout response is null");
    }

    if (raw is! Map) {
      throw Exception("Checkout response is not a map");
    }

    final data = Map<String, dynamic>.from(raw);

    debugPrint("🔥 CHECKOUT RESPONSE DATA: $data");

    return CheckoutSessionResult.fromJson(data);
  } catch (e, st) {
    debugPrint("💥 createCheckoutSession ERROR: $e");
    debugPrint("📍 STACK: $st");
    rethrow;
  }
}
Future<Map<String, dynamic>> calculatePricing({
  required List<Map<String, dynamic>> items,
  required String carrier,
}) async {
  final callable = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  ).httpsCallable('calculatePricing');

  final res = await callable.call({
    "items": items,
    "carrier": carrier,
  });

  return Map<String, dynamic>.from(res.data);
}
}