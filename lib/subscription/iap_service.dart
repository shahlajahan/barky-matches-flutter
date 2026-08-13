import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

bool isAppleSubscriptionOwnershipConflict(FirebaseFunctionsException error) {
  return error.code == 'permission-denied' &&
      const {
        'This Apple purchase is linked to another account',
        'This store purchase is already linked to another account',
      }.contains(error.message);
}

enum _VerificationResult { success, ownershipConflict, failed }

/// Store purchase handling for the two mobile auto-renewable subscriptions.
///
/// The client never derives an entitlement from a product id. It forwards the
/// store's server verification material to the store-specific verifier and
/// completes the store transaction only after that call succeeds.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  static const String premiumMonthlyId = 'barky_premium_monthly';
  static const String goldMonthlyId = 'barky_gold_monthly';

  // Apple products, server verification, and App Store notifications are
  // configured for this release. Product availability still depends on the
  // signed iOS build and the active App Store/Sandbox account.
  static const bool mobileIapEnabled = true;
  static const String ownershipConflictReason = 'ownership_conflict';
  static const String verificationFailedReason = 'verification_failed';
  static const Set<String> _productIds = {premiumMonthlyId, goldMonthlyId};

  static String _accountBindingToken(String uid) {
    final bytes = List<int>.from(sha256.convert(utf8.encode(uid)).bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Future<void>? _initFuture;
  Future<void> Function()? _onSubscriptionActivated;
  Future<void> Function(String reason)? _onSubscriptionError;
  final Set<String> _processingPurchases = <String>{};

  List<ProductDetails> products = <ProductDetails>[];
  bool _isPurchasing = false;

  Future<void> init({Future<void> Function()? onSubscriptionActivated}) async {
    if (_initFuture != null) {
      debugPrint('🛒 STORE INIT REUSE');
      return _initFuture!;
    }
    _initFuture = _initStore(onSubscriptionActivated: onSubscriptionActivated);
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initStore({
    Future<void> Function()? onSubscriptionActivated,
  }) async {
    debugPrint('🛒 STORE INIT START');
    if (onSubscriptionActivated != null) {
      _onSubscriptionActivated = onSubscriptionActivated;
    }
    if (!mobileIapEnabled) {
      debugPrint('🛒 STORE INIT SKIPPED: mobile IAP disabled');
      products = <ProductDetails>[];
      return;
    }

    final available = await _iap.isAvailable();
    debugPrint('🛒 STORE AVAILABLE: $available');
    if (!available) {
      debugPrint('🛒 STORE INIT FAILED: InAppPurchase.isAvailable=false');
      return;
    }

    debugPrint('🛒 PRODUCT QUERY START');
    debugPrint('🛒 PRODUCT IDS: ${_productIds.toList()..sort()}');
    final response = await _iap.queryProductDetails(_productIds);
    debugPrint('🛒 STORE RESPONSE ERROR: ${response.error}');
    debugPrint('🛒 STORE RESPONSE MESSAGE: ${response.error?.message}');
    debugPrint('🛒 PRODUCTS COUNT: ${response.productDetails.length}');
    products = response.productDetails
        .where((product) => _productIds.contains(product.id))
        .toList(growable: false);
    for (final product in products) {
      debugPrint(
        '🛒 PRODUCT FOUND: id=${product.id} price=${product.price} '
        'currency=${product.currencyCode}',
      );
    }
    final foundIds = products.map((product) => product.id).toSet();
    final missingIds = _productIds.difference(foundIds).toList()..sort();
    if (missingIds.isNotEmpty) {
      debugPrint('🛒 PRODUCTS MISSING: $missingIds');
    }
    if (response.error != null) {
      debugPrint('🛒 PRODUCT QUERY FAILED: ${response.error}');
    }
    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      (purchases) => _onPurchaseUpdate(purchases),
      onError: (Object error, StackTrace stack) {
        debugPrint('🛒 PURCHASE STREAM ERROR: $error\n$stack');
      },
    );
    debugPrint('🛒 STORE INIT COMPLETE: products=${products.length}');
  }

  void setSubscriptionActivatedCallback(Future<void> Function() callback) {
    _onSubscriptionActivated = callback;
  }

  void setSubscriptionErrorCallback(
    Future<void> Function(String reason)? callback,
  ) {
    _onSubscriptionError = callback;
  }

  ProductDetails? get premiumProduct =>
      products.where((product) => product.id == premiumMonthlyId).firstOrNull;

  ProductDetails? get goldProduct =>
      products.where((product) => product.id == goldMonthlyId).firstOrNull;

  Future<void> buySubscription(ProductDetails product) async {
    if (!mobileIapEnabled) {
      throw StateError(
        'Mobile IAP is unavailable until verification is configured',
      );
    }
    if (!_productIds.contains(product.id)) {
      throw ArgumentError.value(product.id, 'product', 'Unknown subscription');
    }
    if (_isPurchasing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Login required before purchasing');
    _isPurchasing = true;

    // InAppPurchase exposes applicationUserName to both stores. It must be an
    // opaque one-way value, never a Firebase UID or store account identifier.
    final accountBinding = _accountBindingToken(user.uid);
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: accountBinding,
    );
    try {
      debugPrint('🛒 PURCHASE START: product=${product.id}');
      // Subscriptions are non-consumables in Flutter’s generic API. The store
      // transaction is completed only in _onPurchaseUpdate after verification.
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) _isPurchasing = false;
    } catch (_) {
      _isPurchasing = false;
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    if (!mobileIapEnabled) return;
    debugPrint('🛒 RESTORE START');
    try {
      await _iap.restorePurchases();
      debugPrint('🛒 RESTORE REQUEST SENT');
    } catch (error, stack) {
      debugPrint('🛒 RESTORE ERROR: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        await _processPurchase(purchase);
      } catch (error, stack) {
        // A malformed store event must never escape the stream callback.
        debugPrint('Purchase processing failed: $error\n$stack');
      }
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    debugPrint(
      '🛒 PURCHASE STATUS: status=${purchase.status} '
      'product=${purchase.productID} purchaseId=${purchase.purchaseID} '
      'pendingComplete=${purchase.pendingCompletePurchase}',
    );
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return;
      case PurchaseStatus.canceled:
        _isPurchasing = false;
        return;
      case PurchaseStatus.error:
        debugPrint('Store purchase error: ${purchase.error}');
        _isPurchasing = false;
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }

    final key =
        '${purchase.verificationData.source}:'
        '${purchase.purchaseID ?? purchase.verificationData.serverVerificationData}';
    if (!_processingPurchases.add(key)) return;
    try {
      final verificationResult = await _verifyWithBackend(purchase);
      if (verificationResult != _VerificationResult.success) {
        _isPurchasing = false;
        if (verificationResult == _VerificationResult.ownershipConflict) {
          // Apple verification succeeded, but this Petsupo account cannot
          // claim the already-bound subscription chain. Finish this local
          // StoreKit event so Restore Purchases does not loop indefinitely;
          // this does not transfer or alter the Apple subscription.
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (error, stack) {
              debugPrint(
                '🛒 OWNERSHIP CONFLICT COMPLETION FAILED: $error\n$stack',
              );
            }
          }
          await _onSubscriptionError?.call(ownershipConflictReason);
        } else {
          await _onSubscriptionError?.call(verificationFailedReason);
        }
        return;
      }

      // Entitlement is durable at this point. Clear the UI purchase lock before
      // completion so a completion failure can be retried by the store stream.
      _isPurchasing = false;
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      await _refreshSubscriptionState();
    } finally {
      _processingPurchases.remove(key);
    }
  }

  Future<_VerificationResult> _verifyWithBackend(
    PurchaseDetails purchase,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🛒 FIREBASE SYNC SKIPPED: no authenticated user');
      return _VerificationResult.failed;
    }
    final source = purchase.verificationData.source;
    final serverVerificationData =
        purchase.verificationData.serverVerificationData;
    debugPrint(
      '🛒 FIREBASE SYNC START: store=$source product=${purchase.productID} '
      'purchaseId=${purchase.purchaseID} '
      'verificationPayloadPresent=${serverVerificationData.isNotEmpty} '
      'verificationPayloadLength=${serverVerificationData.length}',
    );
    if (source != 'app_store' && source != 'google_play') {
      debugPrint('🛒 FIREBASE SYNC REJECTED: unsupported store=$source');
      return _VerificationResult.failed;
    }
    if (serverVerificationData.isEmpty) {
      debugPrint('🛒 FIREBASE SYNC REJECTED: missing server verification data');
      return _VerificationResult.failed;
    }
    if (source == 'app_store' &&
        (purchase.purchaseID ?? '').isEmpty &&
        serverVerificationData.split('.').length != 3) {
      debugPrint(
        '🛒 FIREBASE SYNC REJECTED: missing Apple transaction ID and '
        'StoreKit signed transaction payload',
      );
      return _VerificationResult.failed;
    }

    final callableName = source == 'google_play'
        ? 'activateGoogleSubscription'
        : 'activateSubscription';
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable(callableName);
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await callable.call(<String, dynamic>{
          'store': source,
          'purchaseId': purchase.purchaseID,
          'verificationData': serverVerificationData,
          // productID is diagnostic only; the backend does not trust it.
          'productIdHint': purchase.productID,
        });
        debugPrint(
          '🛒 FIREBASE SYNC SUCCESS: store=$source product=${purchase.productID}',
        );
        return _VerificationResult.success;
      } on FirebaseFunctionsException catch (error) {
        debugPrint(
          '🛒 FIREBASE SYNC ERROR: attempt=$attempt code=${error.code} '
          'message=${error.message}',
        );
        if (isAppleSubscriptionOwnershipConflict(error)) {
          return _VerificationResult.ownershipConflict;
        }
        if (error.code == 'permission-denied' ||
            error.code == 'invalid-argument') {
          return _VerificationResult.failed;
        }
      } catch (error) {
        debugPrint('🛒 FIREBASE SYNC ERROR: attempt=$attempt error=$error');
      }
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return _VerificationResult.failed;
  }

  Future<void> _refreshSubscriptionState() async {
    final callback = _onSubscriptionActivated;
    if (callback != null) await callback();
  }

  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
  }
}
