import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  static const String premiumMonthlyId = 'barky_premium_monthly';
  static const String goldMonthlyId = 'barky_gold_monthly';

  static const Set<String> _productIds = {
    premiumMonthlyId,
    goldMonthlyId,
  };

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  List<ProductDetails> products = [];
  bool isStoreAvailable = false;
  bool isLoading = false;

  Future<void> init() async {
  debugPrint('🛒 IAP init started');
  isLoading = true;

  isStoreAvailable = await _iap.isAvailable();
  debugPrint('🛒 Store available = $isStoreAvailable');

  if (!isStoreAvailable) {
    debugPrint('❌ Store not available');
    isLoading = false;
    return;
  }

  debugPrint('🛒 Querying products...');
  debugPrint('🛒 Product IDs: $_productIds');

  final ProductDetailsResponse response =
      await _iap.queryProductDetails(_productIds);

  // 🔥 NEW DEBUG (خیلی مهم)
  debugPrint('🛒 RAW response: $response');

  if (response.error != null) {
    debugPrint('❌ queryProductDetails error: ${response.error}');
  }

  debugPrint('❌ notFoundIDs: ${response.notFoundIDs}');
  debugPrint('✅ productDetails: ${response.productDetails.map((e) => e.id).toList()}');

  if (response.productDetails.isEmpty) {
    debugPrint('🚨 NO PRODUCTS RETURNED FROM APP STORE');
  }

  products = response.productDetails;

  isLoading = false;

  _purchaseSub?.cancel();
  _purchaseSub = _iap.purchaseStream.listen(
    _onPurchaseUpdate,
    onDone: () => _purchaseSub?.cancel(),
    onError: (e) {
      debugPrint('❌ purchaseStream error: $e');
    },
  );
}
  ProductDetails? get premiumProduct {
    try {
      return products.firstWhere((p) => p.id == premiumMonthlyId);
    } catch (_) {
      return null;
    }
  }

  ProductDetails? get goldProduct {
    try {
      return products.firstWhere((p) => p.id == goldMonthlyId);
    } catch (_) {
      return null;
    }
  }

  Future<void> buySubscription(ProductDetails product) async {
    debugPrint('🛒 buySubscription → ${product.id}');

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );

    await _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    debugPrint('♻️ restorePurchases called');
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('🧾 purchase status: ${purchase.status} / ${purchase.productID}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final bool valid = await _verifyPurchaseOnServer(purchase);

          if (valid) {
            await _unlockSubscriptionFromPurchase(purchase);
          } else {
            debugPrint('❌ Purchase verification failed');
          }

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          debugPrint('❌ Purchase error: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('🛑 Purchase canceled');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  Future<bool> _verifyPurchaseOnServer(PurchaseDetails purchase) async {
    debugPrint('🔐 TEMP verify purchase: ${purchase.productID}');
    return true;
  }

  Future<void> _unlockSubscriptionFromPurchase(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      debugPrint('❌ No logged in user for subscription unlock');
      return;
    }

    String plan = 'normal';

    if (purchase.productID == premiumMonthlyId) {
      plan = 'premium';
    } else if (purchase.productID == goldMonthlyId) {
      plan = 'gold';
    } else {
      debugPrint('⚠️ Unknown productID: ${purchase.productID}');
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'subscription': {
        'plan': plan,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    debugPrint('✅ Firestore subscription updated → $plan');
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}