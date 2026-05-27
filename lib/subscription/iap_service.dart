import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  static const String premiumMonthlyId = 'barky_premium_monthly';
  static const String goldMonthlyId = 'barky_gold_monthly';

  static const Set<String> _productIds = {premiumMonthlyId, goldMonthlyId};

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Future<void> Function()? _onSubscriptionActivated;

  List<ProductDetails> products = [];

  bool _isPurchasing = false;
  String? _activeProductId;

  // ─────────────────────────────
  // INIT
  // ─────────────────────────────
  Future<void> init({Future<void> Function()? onSubscriptionActivated}) async {
    if (onSubscriptionActivated != null) {
      _onSubscriptionActivated = onSubscriptionActivated;
    }

    debugPrint('🛒 IAP init started');

    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint('❌ Store not available');
      return;
    }

    final response = await _iap.queryProductDetails(_productIds);

    debugPrint(
      '✅ products: ${response.productDetails.map((e) => e.id).toList()}',
    );

    products = response.productDetails;

    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void setSubscriptionActivatedCallback(Future<void> Function() callback) {
    _onSubscriptionActivated = callback;
  }

  ProductDetails? get premiumProduct =>
      products.where((p) => p.id == premiumMonthlyId).firstOrNull;

  ProductDetails? get goldProduct =>
      products.where((p) => p.id == goldMonthlyId).firstOrNull;

  // ─────────────────────────────
  // BUY
  // ─────────────────────────────
  Future<void> buySubscription(ProductDetails product) async {
    if (_isPurchasing) {
      debugPrint('🛑 already purchasing');
      return;
    }

    await forceCompleteAllTransactions();

    _isPurchasing = true;
    _activeProductId = product.id;

    debugPrint('🛒 BUY → ${product.id}');

    final purchaseParam = PurchaseParam(productDetails: product);

    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
  }

  // ─────────────────────────────
  // RESTORE
  // ─────────────────────────────
  Future<void> restorePurchases() async {
    debugPrint('♻️ restorePurchases');
    await _iap.restorePurchases();
  }

  // ─────────────────────────────
  // PURCHASE LISTENER
  // ─────────────────────────────
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('🧾 status: ${purchase.status}');
      debugPrint('🧾 product: ${purchase.productID}');
      debugPrint('🧾 date: ${purchase.transactionDate}');

      if (_activeProductId != null && purchase.productID != _activeProductId) {
        debugPrint('🛑 ignored other product');
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ pending');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_activeProductId == null) {
            debugPrint('🛑 old purchase ignored');
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            break;
          }

          await _unlockSubscription(purchase);
          debugPrint("🔥 FORCING APPSTATE SUBSCRIPTION RELOAD");
          await _refreshSubscriptionState();
          if (_onSubscriptionActivated != null) {
            await _onSubscriptionActivated!();
          }
          await Future.delayed(const Duration(seconds: 1));

          debugPrint('🔥 POST PURCHASE DELAY FINISHED');

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          _resetState();
          break;

        case PurchaseStatus.error:
          debugPrint('❌ error: ${purchase.error}');
          _resetState();
          break;

        case PurchaseStatus.canceled:
          debugPrint('🛑 canceled');
          _resetState();
          break;
      }
    }
  }

  // ─────────────────────────────
  // CLEAR OLD TRANSACTIONS
  // ─────────────────────────────
  Future<void> forceCompleteAllTransactions() async {
    final sub = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        debugPrint("🧹 cleaning: ${purchase.productID}");
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {}
      }
    });

    await Future.delayed(const Duration(seconds: 2));
    await sub.cancel();
  }

  // ─────────────────────────────
  // UNLOCK
  // ─────────────────────────────
  Future<void> _unlockSubscription(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String plan = purchase.productID == goldMonthlyId ? "gold" : "premium";

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('activateSubscription');
      for (int i = 0; i < 3; i++) {
        try {
          await callable.call({"plan": plan, "productId": purchase.productID});
          break;
        } catch (e) {
          debugPrint("⚠️ retry $i → $e");
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      debugPrint("✅ subscription activated");
      await FirebaseAuth.instance.currentUser?.reload();

      await Future.delayed(const Duration(milliseconds: 800));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': true,
        'subscriptionPlan': plan,
        'subscriptionStatus': 'active',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("❌ cloud error: $e");
    }
  }

  Future<void> _refreshSubscriptionState() async {
    final callback = _onSubscriptionActivated;
    if (callback == null) {
      debugPrint("⚠️ subscription reload skipped: no AppState callback");
      return;
    }

    await callback();
  }

  void _resetState() {
    _isPurchasing = false;
    _activeProductId = null;
  }

  void dispose() {
    _purchaseSub?.cancel();
  }
}
