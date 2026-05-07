import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west3');

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
      if (trackingNumber != null) "trackingNumber": trackingNumber,
      if (carrier != null) "carrier": carrier,
    };

    final res = await callable.call(payload);

    return Map<String, dynamic>.from(res.data as Map);
  }

  /// ⚠️ OLD SYSTEM (KEEP TEMPORARILY)
  Future<String> createOrder({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double kdv,
    required double shippingTotal,
    required double grandTotal,
    required String currency,
    required String businessId,
    required Map<String, dynamic> address,
    required Map<String, dynamic> billing,
    required Map<String, dynamic> legal,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
  }) async {
    debugPrint("⚠️ OLD createOrder USED (SHOULD BE REMOVED LATER)");

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final orderRef = _db.collection('orders').doc();

    await orderRef.set({
      "orderId": orderRef.id,
      "buyerName": buyerName,
      "buyerEmail": buyerEmail,
      "createdAt": FieldValue.serverTimestamp(),
    });

    return orderRef.id;
  }
}