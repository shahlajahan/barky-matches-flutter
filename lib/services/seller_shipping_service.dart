import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seller_shipping_config.dart';
import 'package:flutter/foundation.dart';

class SellerShippingService {
  final _db = FirebaseFirestore.instance;

  // =========================
  // 📡 GET CONFIG
  // =========================
  Future<Map<String, dynamic>> getConfig(String businessId) async {
    final ref = FirebaseFirestore.instance
        .collection('shipping_configs')
        .doc(businessId);

    final doc = await ref.get();

    if (doc.exists) {
      debugPrint("✅ SHIPPING CONFIG FOUND");
      return doc.data()!;
    }

    debugPrint("⚠️ SHIPPING CONFIG NOT FOUND → CREATING...");

    final defaultConfig = {
      "basePrice": 50,
      "pricePerKg": 10,
      "freeShippingThreshold": 500,
      "createdAt": FieldValue.serverTimestamp(),
    };

    await ref.set(defaultConfig);

    debugPrint("✅ SHIPPING CONFIG CREATED");

    return defaultConfig;
  }

  // =========================
  // 💾 SAVE CONFIG
  // =========================
  Future<void> saveConfig(
    String businessId,
    SellerShippingConfig config,
  ) async {
    try {
      await _db
          .collection("businesses")
          .doc(businessId)
          .collection("shipping")
          .doc("config")
          .set(config.toJson(), SetOptions(merge: true));

      debugPrint("✅ SHIPPING CONFIG SAVED");
    } catch (e) {
      debugPrint("❌ saveConfig ERROR: $e");
      rethrow;
    }
  }
}
