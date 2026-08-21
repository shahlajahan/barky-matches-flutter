import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'package:flutter/foundation.dart';

class ProductService {
  final _db = FirebaseFirestore.instance;

  void _validateProduct(Product product) {
    if (product.name.trim().isEmpty) {
      throw Exception("Product name boş olamaz");
    }

    if (product.price <= 0) {
      throw Exception("Fiyat 0'dan büyük olmalı");
    }

    if (product.stock < 0) {
      throw Exception("Stock negatif olamaz");
    }

    // 🔥 SHIPPING VALIDATION
    if (product.isShippable && product.deliveryType == 'cargo') {
      final hasFixed = product.fixedDesi != null && product.fixedDesi! > 0;

      final hasDimensions =
          product.weightKg != null &&
          product.lengthCm != null &&
          product.widthCm != null &&
          product.heightCm != null;

      if (!hasFixed && !hasDimensions) {
        throw Exception("Kargo için ölçü veya desi zorunlu");
      }
    }
  }

  // =========================
  // 📡 GET PRODUCTS (seller's own dashboard/inventory — all statuses)
  // =========================
  Stream<List<Product>> getProducts(String businessId) {
    // Not a public catalog query: intentionally returns every status
    // (pending_review, approved, rejected, inactive) so the owner can see
    // and manage their full inventory. The explicit businessId filter is
    // required for Firestore Rules to prove ownership on a list query, in
    // addition to the path already being scoped to this business.
    return FirebaseFirestore.instance
        .collection("businesses")
        .doc(businessId)
        .collection("products")
        .where("businessId", isEqualTo: businessId)
        .snapshots()
        .handleError((error) {
          debugPrint("🔥 FIRESTORE ERROR: $error");
        })
        .map(
          (snap) => snap.docs
              .map((doc) => Product.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // =========================
  // ➕ ADD PRODUCT
  // =========================
  Future<void> addProduct(String businessId, Product product) async {
    try {
      _validateProduct(product);

      final ref = _db
          .collection("businesses")
          .doc(businessId)
          .collection("products")
          .doc(); // 🔥 auto id

      final newProduct = Product(
        id: ref.id,
        businessId: businessId,

        // 🔁 copy fields
        name: product.name,
        description: product.description,
        price: product.price,
        currency: product.currency,
        media: product.media,
        stock: product.stock,
        category: product.category,
        isActive: product.isActive,

        // optional
        barcode: product.barcode,
        brand: product.brand,
        sku: product.sku,
        salePrice: product.salePrice,
        wholesalePrice: product.wholesalePrice,

        // 🔥 SHIPPING
        isShippable: product.isShippable,
        deliveryType: product.deliveryType,
        weightKg: product.weightKg,
        lengthCm: product.lengthCm,
        widthCm: product.widthCm,
        heightCm: product.heightCm,
        fixedDesi: product.fixedDesi,
        shippingMode: product.shippingMode,
        shippingPayer: product.shippingPayer,
        shippingFee: product.shippingFee,
        freeShippingThreshold: product.freeShippingThreshold,
        allowedCarrierCodes: product.allowedCarrierCodes,

        // timestamps
        createdAt: FieldValue.serverTimestamp() as Timestamp?,
        updatedAt: FieldValue.serverTimestamp() as Timestamp?,
      );

      await ref.set(newProduct.toJson());

      debugPrint("✅ PRODUCT CREATED: ${ref.id}");
    } catch (e) {
      debugPrint("❌ addProduct ERROR: $e");
      rethrow;
    }
  }

  // =========================
  // ❌ DELETE
  // =========================
  Future<void> deleteProduct(String businessId, String productId) async {
    await FirebaseFirestore.instance
        .collection("businesses")
        .doc(businessId)
        .collection("products")
        .doc(productId)
        .delete();
  }

  // =========================
  // ✏️ UPDATE
  // =========================
  Future<void> updateProduct(
    String businessId,
    String productId,
    Product product,
  ) async {
    try {
      _validateProduct(product);

      final ref = _db
          .collection("businesses")
          .doc(businessId)
          .collection("products")
          .doc(productId);

      await ref.set({
        ...product.toJson(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("✏️ PRODUCT UPDATED: $productId");
    } catch (e) {
      debugPrint("❌ updateProduct ERROR: $e");
      rethrow;
    }
  }
}
