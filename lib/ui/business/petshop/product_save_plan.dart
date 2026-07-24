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
