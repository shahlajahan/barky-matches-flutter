import 'product.dart';
import 'product_media.dart';
import 'public_marketplace_product.dart';

// Marketplace Revision 43 §0.41 (Slice 7D) — the ONE adapter from the
// server's public projection to the app's display `Product`.
//
// WHY AN ADAPTER RATHER THAN A UI REWRITE. Every customer surface already
// renders `Product`. Slice 7D changes where that data COMES FROM — the
// trusted callable instead of a direct Firestore read — while deliberately
// preserving user-visible behaviour. Converting at the boundary achieves
// that without touching rendering, cart maths, or promotion logic.
//
// WHAT THIS IS NOT. It is not a rehydration of arbitrary data into a
// purchasable model. It accepts ONLY the server's own public projection,
// which the server emits solely for products that passed
// `evaluateLiveProductEligibility` at request time. There is no path from a
// raw Firestore document, a cache entry, or a client-built map into this
// function.
//
// The two publication fields are pinned rather than copied: the server does
// not project `isActive`/`moderationStatus` (they are forbidden public
// fields), and their only honest local value is the one the server's
// decision already implies. Nothing downstream may re-derive eligibility
// from them — the server's willingness to return the product IS the
// eligibility decision.
extension PublicProductListItemAdapter on PublicProductListItem {
  Product toProduct() => _toProduct(
    businessId: businessId,
    productId: productId,
    name: name,
    description: description,
    category: category,
    brand: brand,
    media: media,
    price: price,
    salePrice: salePrice,
    currency: currency,
    kdvRate: kdvRate,
    taxIncluded: taxIncluded,
    stock: stock,
    shippingMode: shippingMode,
    shippingPayer: shippingPayer,
    shippingFee: shippingFee,
    freeShippingThreshold: freeShippingThreshold,
    allowFreeShipping: allowFreeShipping,
    allowedCarrierCodes: allowedCarrierCodes,
    originCity: originCity,
    maxDeliveryDays: maxDeliveryDays,
    deliveryType: deliveryType,
    weightKg: weightKg,
    lengthCm: lengthCm,
    widthCm: widthCm,
    heightCm: heightCm,
    fixedDesi: fixedDesi,
    businessName: businessName,
    businessLogo: businessLogo,
  );
}

extension PublicProductDetailAdapter on PublicProductDetail {
  Product toProduct() => _toProduct(
    businessId: businessId,
    productId: productId,
    name: name,
    description: description,
    category: category,
    brand: brand,
    media: media,
    price: price,
    salePrice: salePrice,
    currency: currency,
    kdvRate: kdvRate,
    taxIncluded: taxIncluded,
    stock: stock,
    shippingMode: shippingMode,
    shippingPayer: shippingPayer,
    shippingFee: shippingFee,
    freeShippingThreshold: freeShippingThreshold,
    allowFreeShipping: allowFreeShipping,
    allowedCarrierCodes: allowedCarrierCodes,
    originCity: originCity,
    maxDeliveryDays: maxDeliveryDays,
    deliveryType: deliveryType,
    weightKg: weightKg,
    lengthCm: lengthCm,
    widthCm: widthCm,
    heightCm: heightCm,
    fixedDesi: fixedDesi,
    businessName: businessName,
    businessLogo: businessLogo,
  );
}

Product _toProduct({
  required String businessId,
  required String productId,
  required String name,
  required String? description,
  required String category,
  required String? brand,
  required List<PublicProductMedia> media,
  required double price,
  required double? salePrice,
  required String currency,
  required double? kdvRate,
  required bool? taxIncluded,
  required int stock,
  required String? shippingMode,
  required String? shippingPayer,
  required double? shippingFee,
  required double? freeShippingThreshold,
  required bool allowFreeShipping,
  required List<String> allowedCarrierCodes,
  required String? originCity,
  required int? maxDeliveryDays,
  required String? deliveryType,
  required double? weightKg,
  required double? lengthCm,
  required double? widthCm,
  required double? heightCm,
  required double? fixedDesi,
  required String? businessName,
  required String? businessLogo,
}) {
  return Product(
    id: productId,
    businessId: businessId,
    name: name,
    description: description ?? '',
    price: price,
    currency: currency,
    media: media
        .map(
          (m) => ProductMedia(
            type: m.type,
            originalUrl: m.originalUrl ?? '',
            playbackUrl: m.playbackUrl,
            thumbnailUrl: m.thumbnailUrl,
            // The server projects only media it considers publishable, so
            // anything returned is ready to display.
            status: 'ready',
          ),
        )
        .toList(growable: false),
    stock: stock,
    category: category,
    // Pinned, not copied — see the file comment. The server returned this
    // product, which is the eligibility decision; these fields exist only so
    // existing widgets that read them render an available product.
    isActive: true,
    moderationStatus: 'approved',
    brand: brand,
    salePrice: salePrice,
    kdvRate: kdvRate,
    taxIncluded: taxIncluded,
    shippingMode: shippingMode,
    shippingPayer: shippingPayer,
    shippingFee: shippingFee,
    freeShippingThreshold: freeShippingThreshold,
    allowFreeShipping: allowFreeShipping,
    allowedCarrierCodes: allowedCarrierCodes,
    originCity: originCity,
    maxDeliveryDays: maxDeliveryDays,
    deliveryType: deliveryType ?? 'cargo',
    weightKg: weightKg,
    lengthCm: lengthCm,
    widthCm: widthCm,
    heightCm: heightCm,
    fixedDesi: fixedDesi,
    businessName: businessName,
    businessLogo: businessLogo,
  );
}
