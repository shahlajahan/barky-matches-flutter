import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OrderService {

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  );

  /// 🟢 NEW SYSTEM (MAIN)
  Future<Map<String, dynamic>> createMarketplaceOrderV2({
    required Map<String, dynamic> buyer,
    required Map<String, dynamic> billing,
    required Map<String, dynamic> delivery,
    required Map<String, dynamic> payment,
    //required Map<String, dynamic> pricing,
    required List<Map<String, dynamic>> items,
    required String carrier,
    required Map<String, dynamic> legal,
    String? checkoutAttemptId,
  }) async {
    debugPrint("🔥 CALLING CLOUD FUNCTION V2...");

    final callable = _functions.httpsCallable('createMarketplaceOrderV2');

    final res = await callable.call({
      "buyer": buyer,
      "billing": billing,
      "delivery": delivery,
      "payment": payment,
      //"pricing": pricing,
      "items": items,
      "carrier": carrier,
      "legal": legal,
      if (checkoutAttemptId != null && checkoutAttemptId.trim().isNotEmpty)
        "checkoutAttemptId": checkoutAttemptId.trim(),
    });

    debugPrint("✅ FUNCTION RESPONSE: ${res.data}");

    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 🔄 UPDATE SELLER ORDER
  Future<Map<String, dynamic>> updateSellerOrderStatusV2({
    required String sellerOrderId,
    required String status,
    String? trackingNumber,
    String? carrier,
  }) async {
    final callable = _functions.httpsCallable('updateSellerOrderStatusV2');

    final payload = {
      "sellerOrderId": sellerOrderId,
      "status": status,
      "trackingNumber": ?trackingNumber,
      "carrier": ?carrier,
    };

    final res = await callable.call(payload);

    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cancelSellerOrderBeforeShipment({
    required String sellerOrderId,
    required String cancelReason,
  }) async {
    final callable = _functions.httpsCallable(
      'cancelSellerOrderBeforeShipment',
    );
    final result = await callable.call({
      'sellerOrderId': sellerOrderId,
      'cancelReason': cancelReason,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// ⚠️ OLD SYSTEM (KEEP TEMPORARILY)
  // Marketplace Revision 44 §0.42 (Slice 7E) — the legacy `createOrder`
  // is REMOVED.
  //
  // It wrote an `orders` document directly from the client, with a
  // client-supplied businessId and a client-computed subtotal, KDV,
  // shipping total and grand total. Its own comment already said it
  // "SHOULD BE REMOVED LATER". Its single caller, `CheckoutButton`, was
  // unreachable — nothing in lib/ or test/ ever constructed it — so removing
  // both closes a client order-creation path that no journey used.
  //
  // Marketplace checkout goes through `createMarketplaceOrderV2` (above),
  // which derives every commercial value server-side inside a transaction.
  // Firestore Rules now deny direct `orders` creation outright, so a
  // reintroduced client write would fail regardless.

}
