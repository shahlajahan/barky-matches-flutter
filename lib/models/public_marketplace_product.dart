// Marketplace P1-A Slice 4.8 Phase A (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.14 "Exact
// Dart/API model contracts, frozen"): the public, read-only response
// models for `getMarketplaceProductList`/`getMarketplaceProductDetail`
// (`functions/src/marketplace/publicCatalog/marketplaceListing.js`'s own
// `projectPublicProduct`). These models are never written back to
// Firestore, never reused by the seller-facing write model (`Product`),
// and never carry any of the five Rules-reserved compliance names
// (complianceEffectiveStatus, complianceValidUntil, evidenceRevision,
// complianceUpdatedAt, complianceReasonCode), a decision-document path,
// or an evidence/scope/review-event ID — the live server projection
// never emits any of them, and none may be added here even
// speculatively.
//
// Dormant in Phase A: no production call site invokes
// `marketplace_catalog_service.dart` yet (Phase B, not this slice).

/// A single media entry from the public projection. All three URL fields
/// are nullable — the server guarantees only that at least one is
/// non-null, never that `originalUrl` specifically is present. This is
/// why the existing `ProductMedia` (`product_media.dart`, whose
/// `originalUrl` is non-nullable/required) is not reused here — reusing
/// it would throw on a valid server response where only `thumbnailUrl`/
/// `playbackUrl` are set.
class PublicProductMedia {
  final String type;
  final String? originalUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;

  const PublicProductMedia({
    required this.type,
    required this.originalUrl,
    required this.playbackUrl,
    required this.thumbnailUrl,
  });

  factory PublicProductMedia.fromJson(Map<String, dynamic> json) {
    return PublicProductMedia(
      type: json['type'] as String,
      originalUrl: json['originalUrl'] as String?,
      playbackUrl: json['playbackUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key is required and must be a string');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key is required and must be a number');
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : null;
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('$key is required and must be an int');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key is required and must be a bool');
  }
  return value;
}

List<PublicProductMedia> _requireMedia(Map<String, dynamic> json) {
  final value = json['media'];
  if (value is! List) {
    throw FormatException('media is required and must be a list');
  }
  // Preserves the server's own source-array order exactly — never
  // re-sorted client-side (§0.14 "Media ordering").
  return value
      .map((e) => PublicProductMedia.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<String> _requireCarrierCodes(Map<String, dynamic> json) {
  final value = json['allowedCarrierCodes'];
  if (value is! List) {
    throw FormatException('allowedCarrierCodes is required and must be a list');
  }
  return value.map((e) => e.toString()).toList(growable: false);
}

/// Fields shared by both public projections. `PublicProductListItem` and
/// `PublicProductDetail` are kept as two distinct classes (never a single
/// shared/aliased type) so the compiler enforces the ≤1-vs-≤20
/// media-cardinality distinction at every call site — the cardinality
/// difference is a server-side cap, never independently re-validated or
/// re-capped in Dart.
abstract class _PublicProductFields {
  final String businessId;
  final String productId;
  final String name;
  final String? description;
  final String category;
  final String? brand;
  final List<PublicProductMedia> media;
  final double price;
  final double? salePrice;
  final String currency;
  final double? kdvRate;
  final bool? taxIncluded;
  final int stock;
  final String? shippingMode;
  final String? shippingPayer;
  final double? shippingFee;
  final double? freeShippingThreshold;
  final bool allowFreeShipping;
  final List<String> allowedCarrierCodes;
  final String? originCity;
  final int? maxDeliveryDays;
  final String? deliveryType;
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? fixedDesi;
  final String? businessName;
  final String? businessLogo;

  const _PublicProductFields({
    required this.businessId,
    required this.productId,
    required this.name,
    required this.description,
    required this.category,
    required this.brand,
    required this.media,
    required this.price,
    required this.salePrice,
    required this.currency,
    required this.kdvRate,
    required this.taxIncluded,
    required this.stock,
    required this.shippingMode,
    required this.shippingPayer,
    required this.shippingFee,
    required this.freeShippingThreshold,
    required this.allowFreeShipping,
    required this.allowedCarrierCodes,
    required this.originCity,
    required this.maxDeliveryDays,
    required this.deliveryType,
    required this.weightKg,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.fixedDesi,
    required this.businessName,
    required this.businessLogo,
  });
}

/// `getMarketplaceProductList`'s own `items[]` entry — `media` is capped
/// at ≤1 by the server (`LIST_MEDIA_CAP`) and is a preview only, never a
/// complete gallery.
class PublicProductListItem extends _PublicProductFields {
  const PublicProductListItem({
    required super.businessId,
    required super.productId,
    required super.name,
    required super.description,
    required super.category,
    required super.brand,
    required super.media,
    required super.price,
    required super.salePrice,
    required super.currency,
    required super.kdvRate,
    required super.taxIncluded,
    required super.stock,
    required super.shippingMode,
    required super.shippingPayer,
    required super.shippingFee,
    required super.freeShippingThreshold,
    required super.allowFreeShipping,
    required super.allowedCarrierCodes,
    required super.originCity,
    required super.maxDeliveryDays,
    required super.deliveryType,
    required super.weightKg,
    required super.lengthCm,
    required super.widthCm,
    required super.heightCm,
    required super.fixedDesi,
    required super.businessName,
    required super.businessLogo,
  });

  factory PublicProductListItem.fromJson(Map<String, dynamic> json) {
    return PublicProductListItem(
      businessId: _requireString(json, 'businessId'),
      productId: _requireString(json, 'productId'),
      name: _requireString(json, 'name'),
      description: _optionalString(json, 'description'),
      category: _requireString(json, 'category'),
      brand: _optionalString(json, 'brand'),
      media: _requireMedia(json),
      price: _requireDouble(json, 'price'),
      salePrice: _optionalDouble(json, 'salePrice'),
      currency: _requireString(json, 'currency'),
      kdvRate: _optionalDouble(json, 'kdvRate'),
      taxIncluded: _optionalBool(json, 'taxIncluded'),
      stock: _requireInt(json, 'stock'),
      shippingMode: _optionalString(json, 'shippingMode'),
      shippingPayer: _optionalString(json, 'shippingPayer'),
      shippingFee: _optionalDouble(json, 'shippingFee'),
      freeShippingThreshold: _optionalDouble(json, 'freeShippingThreshold'),
      allowFreeShipping: _requireBool(json, 'allowFreeShipping'),
      allowedCarrierCodes: _requireCarrierCodes(json),
      originCity: _optionalString(json, 'originCity'),
      maxDeliveryDays: _optionalInt(json, 'maxDeliveryDays'),
      deliveryType: _optionalString(json, 'deliveryType'),
      weightKg: _optionalDouble(json, 'weightKg'),
      lengthCm: _optionalDouble(json, 'lengthCm'),
      widthCm: _optionalDouble(json, 'widthCm'),
      heightCm: _optionalDouble(json, 'heightCm'),
      fixedDesi: _optionalDouble(json, 'fixedDesi'),
      businessName: _optionalString(json, 'businessName'),
      businessLogo: _optionalString(json, 'businessLogo'),
    );
  }
}

/// `getMarketplaceProductDetail`'s own `item` — `media` carries every
/// entry the server returned (0-20, `DETAIL_MEDIA_CAP`), the complete,
/// authoritative gallery.
class PublicProductDetail extends _PublicProductFields {
  const PublicProductDetail({
    required super.businessId,
    required super.productId,
    required super.name,
    required super.description,
    required super.category,
    required super.brand,
    required super.media,
    required super.price,
    required super.salePrice,
    required super.currency,
    required super.kdvRate,
    required super.taxIncluded,
    required super.stock,
    required super.shippingMode,
    required super.shippingPayer,
    required super.shippingFee,
    required super.freeShippingThreshold,
    required super.allowFreeShipping,
    required super.allowedCarrierCodes,
    required super.originCity,
    required super.maxDeliveryDays,
    required super.deliveryType,
    required super.weightKg,
    required super.lengthCm,
    required super.widthCm,
    required super.heightCm,
    required super.fixedDesi,
    required super.businessName,
    required super.businessLogo,
  });

  factory PublicProductDetail.fromJson(Map<String, dynamic> json) {
    return PublicProductDetail(
      businessId: _requireString(json, 'businessId'),
      productId: _requireString(json, 'productId'),
      name: _requireString(json, 'name'),
      description: _optionalString(json, 'description'),
      category: _requireString(json, 'category'),
      brand: _optionalString(json, 'brand'),
      media: _requireMedia(json),
      price: _requireDouble(json, 'price'),
      salePrice: _optionalDouble(json, 'salePrice'),
      currency: _requireString(json, 'currency'),
      kdvRate: _optionalDouble(json, 'kdvRate'),
      taxIncluded: _optionalBool(json, 'taxIncluded'),
      stock: _requireInt(json, 'stock'),
      shippingMode: _optionalString(json, 'shippingMode'),
      shippingPayer: _optionalString(json, 'shippingPayer'),
      shippingFee: _optionalDouble(json, 'shippingFee'),
      freeShippingThreshold: _optionalDouble(json, 'freeShippingThreshold'),
      allowFreeShipping: _requireBool(json, 'allowFreeShipping'),
      allowedCarrierCodes: _requireCarrierCodes(json),
      originCity: _optionalString(json, 'originCity'),
      maxDeliveryDays: _optionalInt(json, 'maxDeliveryDays'),
      deliveryType: _optionalString(json, 'deliveryType'),
      weightKg: _optionalDouble(json, 'weightKg'),
      lengthCm: _optionalDouble(json, 'lengthCm'),
      widthCm: _optionalDouble(json, 'widthCm'),
      heightCm: _optionalDouble(json, 'heightCm'),
      fixedDesi: _optionalDouble(json, 'fixedDesi'),
      businessName: _optionalString(json, 'businessName'),
      businessLogo: _optionalString(json, 'businessLogo'),
    );
  }
}
