import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import 'package:flutter/foundation.dart';

import 'marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller, marketplaceFunctionsRegion;

/// The outcome of a successful [ProductService.deleteMarketplaceProduct]
/// call — both are treated identically as success by every caller
/// (Marketplace P1-A Slice 4.10, docs/plans/marketplace_p1a_compliance_
/// review_implementation_plan_2026-08-21.md §0.17 Phase 13, committed
/// Revision 19).
enum ProductDeletionOutcome {
  /// The product, its decision, and its evidence links were physically
  /// deleted by this call.
  deleted,

  /// A prior call with the same idempotency key already completed this
  /// exact deletion — a pure, zero-write replay.
  replayed,
}

/// Typed result of [ProductService.deleteMarketplaceProduct].
class ProductDeletionResult {
  final ProductDeletionOutcome outcome;
  final String productId;

  const ProductDeletionResult({required this.outcome, required this.productId});
}

/// A typed classification of why [ProductService.deleteMarketplaceProduct]
/// did not return a usable result — never a raw, generic exception string
/// (§0.17 Phase 6's own frozen `reasonCode` contract, mirrored here).
enum ProductDeletionFailureKind {
  unauthenticated,
  invalidRequest,
  businessNotFound,
  productNotFound,
  notBusinessOwner,
  businessIdMismatch,
  idempotencyKeyConflict,
  malformedDecisionState,
  internalError,

  /// A response missing `status`/`productId`, or an unrecognized `status`
  /// value — the live server contract never actually produces this, but
  /// a malformed/mocked response could; never silently coerced to success.
  unavailableRetry,

  /// Any other `FirebaseFunctionsException` code with no recognized
  /// `reasonCode`, or any other unexpected failure.
  generic,
}

/// Thrown by [ProductService.deleteMarketplaceProduct] on any non-success
/// outcome — a typed result, never a bare/generic exception.
class ProductDeletionException implements Exception {
  final ProductDeletionFailureKind kind;

  const ProductDeletionException(this.kind);

  @override
  String toString() => 'ProductDeletionException($kind)';
}

/// Generates a fresh, opaque client idempotency key — call this exactly
/// once per logical delete attempt, at the moment the user confirms, and
/// reuse the same value for every retry of that same attempt (§0.17
/// Phase 13). Never generate a new key on retry — that would defeat the
/// receipt's own idempotency guarantee.
String generateProductDeletionIdempotencyKey() => const Uuid().v4();

class ProductService {
  ProductService({
    FirebaseFunctions? functions,
    MarketplaceFunctionCaller? callableInvoker,
  }) : _callableInvoker = callableInvoker ?? _defaultInvoker(functions);

  static MarketplaceFunctionCaller _defaultInvoker(
    FirebaseFunctions? functions,
  ) {
    final resolved =
        functions ??
        FirebaseFunctions.instanceFor(region: marketplaceFunctionsRegion);
    return (name, data) async {
      final result = await resolved.httpsCallable(name).call(data);
      return result.data;
    };
  }

  final MarketplaceFunctionCaller _callableInvoker;

  // Lazy, not an eagerly-initialized field: constructing ProductService()
  // must not itself touch FirebaseFirestore.instance (which requires
  // Firebase.initializeApp() to have already run) for callers that only
  // exercise the callable-based deleteMarketplaceProduct method — e.g.
  // product_service_test.dart's own fake-callable unit tests, which
  // never initialize Firebase at all.
  FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ??= FirebaseFirestore.instance;

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
  // ➕ ADD PRODUCT — REMOVED (Marketplace Revision 34)
  // =========================
  // `addProduct` wrote a product directly through the client SDK at an
  // auto-generated document ID. It was already unreachable — no caller
  // existed anywhere in lib/, test/ or integration_test/ — and it
  // contradicted two committed contracts at once:
  //
  //   * Revision 19's deterministic product identity
  //     `${businessId}_${normalizedSku}`, which an auto ID cannot produce;
  //     and
  //   * Revision 34's closure of direct client-SDK product creation
  //     (`allow create: if false` in firestore.rules), under which any such
  //     write is denied at the server anyway.
  //
  // Products are created exclusively by the `submitMarketplaceProduct`
  // callable (Admin SDK), which derives the ID, the generation binding and
  // every value check server-side. This mirrors how the direct client
  // delete was retired in Revision 19 in favour of `deleteMarketplaceProduct`
  // below. `_validateProduct` is deliberately retained: `updateProduct`
  // still uses it, and its update contract remains legitimate.

  // =========================
  // ❌ DELETE — Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_
  // compliance_review_implementation_plan_2026-08-21.md §0.17 Phase 10,
  // committed Revision 19). The prior direct, non-transactional
  // Firestore delete call is retired — firestore.rules now denies every
  // direct client-SDK product delete unconditionally, admin included
  // (§9.E). Physical deletion routes exclusively through the new
  // server-authoritative `deleteMarketplaceProduct` callable, which
  // atomically deletes the product together with its compliance
  // decision and evidence links.
  // =========================
  Future<ProductDeletionResult> deleteMarketplaceProduct({
    required String businessId,
    required String productId,
    required String clientIdempotencyKey,
  }) async {
    final Object? data;
    try {
      data = await _callableInvoker('deleteMarketplaceProduct', {
        'businessId': businessId,
        'productId': productId,
        'clientIdempotencyKey': clientIdempotencyKey,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ProductDeletionException(_mapDeletionFailure(e));
    }

    if (data is! Map) {
      throw const ProductDeletionException(
        ProductDeletionFailureKind.unavailableRetry,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final status = map['status'];
    final resultProductId = map['productId'];
    if (resultProductId is! String ||
        (status != 'deleted' && status != 'replayed')) {
      throw const ProductDeletionException(
        ProductDeletionFailureKind.unavailableRetry,
      );
    }
    return ProductDeletionResult(
      outcome: status == 'deleted'
          ? ProductDeletionOutcome.deleted
          : ProductDeletionOutcome.replayed,
      productId: resultProductId,
    );
  }

  ProductDeletionFailureKind _mapDeletionFailure(FirebaseFunctionsException e) {
    final details = e.details;
    final reasonCode = details is Map ? details['reasonCode'] : null;
    switch (reasonCode) {
      case 'unauthenticated':
        return ProductDeletionFailureKind.unauthenticated;
      case 'invalid_request':
        return ProductDeletionFailureKind.invalidRequest;
      case 'business_not_found':
        return ProductDeletionFailureKind.businessNotFound;
      case 'product_not_found':
        return ProductDeletionFailureKind.productNotFound;
      case 'not_business_owner':
        return ProductDeletionFailureKind.notBusinessOwner;
      case 'business_id_mismatch':
        return ProductDeletionFailureKind.businessIdMismatch;
      case 'idempotency_key_conflict':
        return ProductDeletionFailureKind.idempotencyKeyConflict;
      case 'malformed_decision_state':
        return ProductDeletionFailureKind.malformedDecisionState;
      case 'internal_error':
        return ProductDeletionFailureKind.internalError;
    }
    // Fallback by HttpsError code alone, for a genuinely unexpected
    // server error that never attached a reasonCode.
    switch (e.code) {
      case 'unauthenticated':
        return ProductDeletionFailureKind.unauthenticated;
      case 'invalid-argument':
        return ProductDeletionFailureKind.invalidRequest;
      case 'not-found':
        return ProductDeletionFailureKind.productNotFound;
      case 'permission-denied':
        return ProductDeletionFailureKind.notBusinessOwner;
      case 'already-exists':
        return ProductDeletionFailureKind.idempotencyKeyConflict;
      case 'failed-precondition':
        return ProductDeletionFailureKind.malformedDecisionState;
      case 'internal':
        return ProductDeletionFailureKind.internalError;
      default:
        return ProductDeletionFailureKind.generic;
    }
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
