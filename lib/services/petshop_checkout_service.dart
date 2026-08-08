import 'package:cloud_functions/cloud_functions.dart';

class CheckoutSessionResult {
  final String orderId;
  final String provider;
  final String? checkoutUrl;
  final String? html;
  final String? token;
  final String? gatewayUrl;
  final String? storeType;
  final String? hashAlgorithm;
  final Map<String, dynamic>? pricing;

  const CheckoutSessionResult({
    required this.orderId,
    required this.provider,
    this.checkoutUrl,
    this.html,
    this.token,
    this.gatewayUrl,
    this.storeType,
    this.hashAlgorithm,
    this.pricing,
  });

  bool get isIsbank => provider.trim().toLowerCase() == "isbank";
  bool get isIyziCo => provider.trim().toLowerCase() == "iyzico";

  factory CheckoutSessionResult.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionResult(
      orderId: (json['orderId'] ?? '') as String,
      provider: (json['provider'] ?? 'iyzico') as String,
      checkoutUrl: json['checkoutUrl']?.toString(),
      html: (json['html'] ?? json['checkoutHtml'])?.toString(),
      token: json['token'] as String?,
      gatewayUrl: json['gatewayUrl']?.toString(),
      storeType: json['storeType']?.toString(),
      hashAlgorithm: json['hashAlgorithm']?.toString(),
      pricing: json['pricing'] != null
          ? Map<String, dynamic>.from(json['pricing'])
          : null,
    );
  }
}

class PetshopCheckoutService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  );

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
    if (items.isEmpty) {
      throw Exception("Cart is empty");
    }

    final callable = _functions.httpsCallable(
      'createCheckoutSession',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
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

    final response = await callable.call(payload);
    final raw = response.data;

    if (raw == null) {
      throw Exception("Checkout response is null");
    }

    if (raw is! Map) {
      throw Exception("Checkout response is not a map");
    }

    final data = Map<String, dynamic>.from(raw);

    return CheckoutSessionResult.fromJson(data);
  }

  Future<Map<String, dynamic>> readPaymentStatusByOrderId(String orderId) async {
    final callable = _functions.httpsCallable(
      'readPaymentStatusByOrderId',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );

    final response = await callable.call({"orderId": orderId});
    final raw = response.data;

    if (raw is! Map) {
      throw StateError("Payment status response is not a map");
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>?> waitForPaymentConfirmation(
    String orderId, {
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(milliseconds: 1200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Map<String, dynamic>? lastResponse;

    while (true) {
      try {
        lastResponse = await readPaymentStatusByOrderId(orderId);
        final paymentStatus =
            lastResponse['paymentStatus']?.toString().trim().toLowerCase() ?? '';
        final orderStatus =
            lastResponse['orderStatus']?.toString().trim().toLowerCase() ?? '';
        final paid = lastResponse['paid'] == true;

        if (paid || paymentStatus == 'failed' || orderStatus == 'payment_failed') {
          return lastResponse;
        }
      } catch (_) {
        // Keep polling until the backend callback settles or the timeout expires.
      }

      if (DateTime.now().isAfter(deadline)) {
        return lastResponse;
      }

      await Future.delayed(pollInterval);
    }
  }

  Future<Map<String, dynamic>> calculatePricing({
    required List<Map<String, dynamic>> items,
    required String carrier,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('calculatePricing');

    final res = await callable.call({"items": items, "carrier": carrier});

    return Map<String, dynamic>.from(res.data);
  }
}
