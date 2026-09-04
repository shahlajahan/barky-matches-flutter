import 'package:firebase_storage/firebase_storage.dart';

import 'product_submit_exception.dart';

enum ProductWriteMode { create, sameIdEdit, skuChangingEdit }

class ProductSavePlan {
  final String businessId;
  final String targetProductId;
  final String? originalProductId;
  final ProductWriteMode mode;

  const ProductSavePlan({
    required this.businessId,
    required this.targetProductId,
    required this.originalProductId,
    required this.mode,
  });

  factory ProductSavePlan.resolve({
    required String businessId,
    required String normalizedSku,
    String? originalProductId,
  }) {
    final targetProductId = '${businessId}_$normalizedSku';
    final originalId = originalProductId?.trim();
    final mode = originalId == null || originalId.isEmpty
        ? ProductWriteMode.create
        : originalId == targetProductId
        ? ProductWriteMode.sameIdEdit
        : ProductWriteMode.skuChangingEdit;

    return ProductSavePlan(
      businessId: businessId,
      targetProductId: targetProductId,
      originalProductId: originalId,
      mode: mode,
    );
  }
}

/// Stable, machine-readable reason codes a product submission may fail with.
///
/// Declared here, ahead of the submission path that will emit them, so the
/// client error contract is a single frozen vocabulary rather than a set of
/// ad-hoc strings discovered at each call site. Codes not yet reachable in
/// production are included deliberately: the mapping must already be correct
/// on the day the emitting path is enabled.
class ProductSubmissionReason {
  const ProductSubmissionReason._();

  static const String marketplaceDisabled = 'marketplace_disabled';
  static const String sellerActivationRequired = 'seller_activation_required';
  static const String invalidSellerRelationship = 'invalid_seller_relationship';
  static const String invalidProductData = 'invalid_product_data';
  static const String duplicateSku = 'duplicate_sku';
  static const String permissionDenied = 'permission_denied';
  static const String uploadFailed = 'upload_failed';
  static const String productSubmissionFailed = 'product_submission_failed';

  /// Marketplace Revision 33/34: the deterministic product ID
  /// `${businessId}_${normalizedSku}` is occupied by a product bound to a
  /// PREVIOUS business generation whose authoritative cleanup has not
  /// finished yet. Deliberately distinct from [duplicateSku]: the seller's
  /// SKU is not taken by a live product of theirs, the slot is merely still
  /// being reclaimed, and retrying shortly succeeds. Collapsing the two
  /// would tell the seller to change a SKU that is in fact free.
  static const String previousGenerationCleanupPending =
      'previous_generation_cleanup_pending';

  static const Set<String> values = {
    marketplaceDisabled,
    sellerActivationRequired,
    invalidSellerRelationship,
    invalidProductData,
    duplicateSku,
    permissionDenied,
    uploadFailed,
    productSubmissionFailed,
    previousGenerationCleanupPending,
  };
}

/// Extracts a stable, mappable code from an arbitrary thrown object.
///
/// Order: a recognized `details.reasonCode` from a callable, then the raw
/// `FirebaseException`/`FirebaseFunctionsException` code, then the legacy
/// [ProductSubmitException] code. Returns null only when the error carries
/// nothing recognizable, so callers can distinguish a known, mappable
/// failure from a genuinely unexpected one instead of collapsing both into
/// one generic message — the defect this contract exists to close.
String? productSubmissionReasonOf(Object error) {
  if (error is ProductSubmitException) return error.code;
  dynamic dynamicError = error;
  try {
    final details = dynamicError.details;
    if (details is Map) {
      final reason = details['reasonCode'];
      if (reason is String && ProductSubmissionReason.values.contains(reason)) {
        return reason;
      }
    }
  } catch (_) {
    // No `details` on this error type; fall through to the raw code.
  }
  try {
    final code = dynamicError.code;
    if (code is String && code.isNotEmpty) return code;
  } catch (_) {
    // Not a Firebase-shaped error.
  }
  return null;
}

List<String> normalizeCarrierCodes(Iterable<String> carriers) {
  return carriers
      .map((carrier) => carrier.trim().toUpperCase())
      .where((carrier) => carrier.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

bool isAuthorizedBusinessEditor({
  required String authUid,
  String? authEmail,
  String? ownerUid,
  String? contactEmail,
  bool isAdmin = false,
}) {
  final normalizedAuthEmail = authEmail?.trim().toLowerCase();
  final normalizedContactEmail = contactEmail?.trim().toLowerCase();
  return isAdmin ||
      ownerUid?.trim() == authUid ||
      (normalizedAuthEmail != null &&
          normalizedAuthEmail.isNotEmpty &&
          normalizedAuthEmail == normalizedContactEmail);
}

T preserveCreatedAt<T>(T? existingCreatedAt, T now) {
  return existingCreatedAt ?? now;
}

Future<bool> runProductSecondarySync(
  Future<void> Function() synchronize, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    await synchronize();
    return true;
  } catch (error, stackTrace) {
    onError(error, stackTrace);
    return false;
  }
}

/// Fields the server alone owns on a Marketplace product document.
///
/// Kept byte-identical to `SERVER_OWNED_SUBMIT_FIELDS` in
/// `functions/src/marketplace/product/submitMarketplaceProduct.js`.
/// `pilotProductClass` is included per Revision 31 §C: server/admin-owned,
/// never seller-writable.
const Set<String> kServerOwnedProductSubmitFields = {
  'isActive',
  'moderationStatus',
  'productInputRevision',
  'createdAt',
  'updatedAt',
  'businessId',
  'sku',
  'productId',
  'marketplaceBusinessGenerationId',
  'pilotProductApproval',
  'pilotProductClass',
  'complianceEffectiveStatus',
  'complianceValidUntil',
  'evidenceRevision',
  'complianceUpdatedAt',
  'complianceReasonCode',
  'reservedStock',
  'inventorySchemaVersion',
  'inventoryOperationVersion',
  'inventoryUpdatedAt',
  'reviewedBy',
  'reviewedAt',
};

/// Deletes Storage objects a failed product submission left unreferenced.
///
/// Lives here rather than in `add_product_page.dart` because §15's Slice 4.8
/// Phase A source proof requires that file to contain no delete call of any
/// kind. Best-effort: a cleanup failure never replaces the real submission
/// error the caller is about to surface.
Future<void> deleteUploadedProductMedia(
  List<Reference> refs, {
  required void Function(Object error) onError,
}) async {
  for (final ref in refs) {
    try {
      await ref.delete();
    } catch (error) {
      onError(error);
    }
  }
}
