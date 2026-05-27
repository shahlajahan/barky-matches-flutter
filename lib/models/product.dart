import 'product_media.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String businessId;

  // 🔥 CORE
  final String name;
  final String description;
  final double price;
  final String currency;

  // 🔥 MEDIA
  final List<ProductMedia> media;

  // 🔥 INVENTORY
  final int stock;
  final int? minStock; // 🔥 low stock alert

  // 🔥 CLASSIFICATION
  final String category;
  final String? brand;

  // 🔥 IDENTIFIERS
  final String? barcode;
  final String? sku;

  // 🔥 STATUS
  final bool isActive;

  // 🔥 PRICING
  final double? salePrice;

  // 🔥 PRICING
  final double? wholesalePrice; // 🏪 فقط برای فروشنده‌ها

  final double? suggestedPrice;
  final double? suggestedMinPrice;
  final double? suggestedMaxPrice;
  final String? pricePosition; // underpriced | competitive | overpriced
  final double? marginPercent;
  final double? markupPercent;
  final bool hasSmartPricing;
  final double? finalRecommendedPrice;
  final String? pricingStrategy;

  // 🔥 SHIPPING (TRENDYOL LEVEL)

  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? fixedDesi;

  final String?
  shippingMode; // carrier_calculated | fixed_price | free_shipping | seller_absorbs
  final String? shippingPayer; // buyer | seller | conditional

  final double? shippingFee;
  final double? freeShippingThreshold;
  final String? originCity;

  final Map<String, dynamic>? shippingProfile;
  final bool? taxIncluded;

  final int? preparationDays;
  final int? maxDeliveryDays;

  final bool allowFreeShipping;

  final bool allowPickup;
  final bool allowSameDay;

  final bool isFragile;
  final bool isPerishable;
  final bool isOversize;

  final bool allowReturns;
  final int? returnWindowDays;

  final String? returnShippingPayer;
  final bool hasContractedReturnCarrier;
  final String? returnCarrierCode;

  final List<String> allowedCarrierCodes;
  final List<String> excludedCities;

  final bool isShippable;
  final String deliveryType;
  final Map<String, dynamic>? shippingSnapshot;
  // cargo | pickup | local_delivery | digital

  // 🔥 TIMESTAMPS
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  final String? businessName;
  final String? businessLogo;
  final double? kdvRate;

  double get finalPrice => salePrice ?? price;

  Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.media,
    required this.stock,
    required this.category,
    required this.isActive,

    this.barcode,
    this.brand,
    this.sku,
    this.salePrice,
    this.wholesalePrice,
    this.suggestedPrice,
    this.suggestedMinPrice,
    this.suggestedMaxPrice,
    this.pricePosition,
    this.finalRecommendedPrice,
    this.pricingStrategy,
    this.marginPercent,
    this.markupPercent,
    this.hasSmartPricing = false,
    this.shippingFee,
    this.freeShippingThreshold,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.fixedDesi,
    this.shippingSnapshot,
    this.shippingProfile,
    this.taxIncluded,

    this.shippingMode,
    this.shippingPayer,
    this.originCity,

    this.preparationDays,
    this.maxDeliveryDays,

    this.allowFreeShipping = false,
    this.isShippable = true,
    this.deliveryType = 'cargo',

    this.allowPickup = false,
    this.allowSameDay = false,

    this.isFragile = false,
    this.isPerishable = false,
    this.isOversize = false,

    this.allowReturns = false,
    this.returnWindowDays,

    this.returnShippingPayer,
    this.hasContractedReturnCarrier = false,
    this.returnCarrierCode,

    this.allowedCarrierCodes = const [],
    this.excludedCities = const [],
    this.minStock,
    this.createdAt,
    this.updatedAt,
    this.businessName,
    this.businessLogo,
    this.kdvRate,
  });

  // =====================================================
  // 🔥 FROM JSON
  // =====================================================
  factory Product.fromJson(String id, Map<String, dynamic> json) {
    final mediaList = json['media'];

    List<ProductMedia> parsedMedia;

    if (mediaList != null) {
      parsedMedia = (mediaList as List<dynamic>)
          .map(
            (e) => ProductMedia.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } else {
      // 🔥 fallback قدیمی
      final images = List<String>.from(json['images'] ?? []);

      parsedMedia = images.map((url) {
        final lower = url.toLowerCase();
        final isVideo =
            lower.contains('.mp4') ||
            lower.contains('.mov') ||
            lower.contains('.webm') ||
            lower.contains('.hevc');

        return ProductMedia(
          type: isVideo ? 'video' : 'image',
          originalUrl: url,
          playbackUrl: isVideo ? url : null,
          thumbnailUrl: isVideo ? null : url,
          status: 'ready',
        );
      }).toList();
    }

    return Product(
      id: id,
      businessId: json['businessId'] ?? '',

      name: json['name'] ?? '',
      description: json['description'] ?? '',

      price: (json['price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),

      suggestedPrice: (json['suggestedPrice'] as num?)?.toDouble(),
      suggestedMinPrice: (json['suggestedMinPrice'] as num?)?.toDouble(),
      suggestedMaxPrice: (json['suggestedMaxPrice'] as num?)?.toDouble(),
      pricePosition: json['pricePosition'],
      marginPercent: (json['marginPercent'] as num?)?.toDouble(),
      markupPercent: (json['markupPercent'] as num?)?.toDouble(),
      hasSmartPricing: json['hasSmartPricing'] ?? false,
      finalRecommendedPrice: (json["finalRecommendedPrice"] as num?)
          ?.toDouble(),
      pricingStrategy: json["pricingStrategy"],
      kdvRate: (json["kdvRate"] as num?)?.toDouble(),

      shippingFee: (json['shippingFee'] as num?)?.toDouble(),
      freeShippingThreshold: (json['freeShippingThreshold'] as num?)
          ?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      lengthCm: (json['lengthCm'] as num?)?.toDouble(),
      widthCm: (json['widthCm'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      fixedDesi: (json['fixedDesi'] as num?)?.toDouble(),

      shippingMode: json['shippingMode'],
      shippingPayer: json['shippingPayer'],
      isShippable: json['isShippable'] ?? true,
      deliveryType: json['deliveryType'] ?? 'cargo',
      originCity: json["originCity"],
      shippingProfile: json["shippingProfile"],
      taxIncluded: json["taxIncluded"],

      preparationDays: json['preparationDays'],
      maxDeliveryDays: json['maxDeliveryDays'],

      allowFreeShipping: json['allowFreeShipping'] ?? false,

      allowPickup: json['allowPickup'] ?? false,
      allowSameDay: json['allowSameDay'] ?? false,

      isFragile: json['isFragile'] ?? false,
      isPerishable: json['isPerishable'] ?? false,
      isOversize: json['isOversize'] ?? false,

      allowReturns: json['allowReturns'] ?? false,
      returnWindowDays: json['returnWindowDays'],

      returnShippingPayer: json['returnShippingPayer'],
      hasContractedReturnCarrier: json['hasContractedReturnCarrier'] ?? false,
      returnCarrierCode: json['returnCarrierCode'],

      allowedCarrierCodes:
          (json['allowedCarrierCodes'] as List?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          [],

      excludedCities: List<String>.from(json['excludedCities'] ?? []),

      currency: json['currency'] ?? 'TRY',

      businessName: json['businessName'],
      businessLogo: json['businessLogo'],

      media: parsedMedia,

      stock: json['stock'] ?? 0,
      minStock: json['minStock'],

      category: json['category'] ?? '',
      brand: json['brand'],

      barcode: json['barcode'],
      sku: json['sku'],

      isActive: json['isActive'] ?? true,

      createdAt: json['createdAt'] is Timestamp ? json['createdAt'] : null,

      updatedAt: json['updatedAt'] is Timestamp ? json['updatedAt'] : null,
    );
  }

  // =====================================================
  // 🔥 TO JSON (Firestore)
  // =====================================================
  Map<String, dynamic> toJson() {
    return {
      "businessId": businessId,

      "name": name,
      "description": description,
      "productId": id,
      "price": price,
      "salePrice": salePrice,
      "wholesalePrice": wholesalePrice,
      "kdvRate": kdvRate,

      "suggestedPrice": suggestedPrice,
      "suggestedMinPrice": suggestedMinPrice,
      "suggestedMaxPrice": suggestedMaxPrice,
      "pricePosition": pricePosition,
      "marginPercent": marginPercent,
      "markupPercent": markupPercent,
      "hasSmartPricing": hasSmartPricing,

      "shippingFee": shippingFee,
      "freeShippingThreshold": freeShippingThreshold,
      "weightKg": weightKg,
      "lengthCm": lengthCm,
      "widthCm": widthCm,
      "heightCm": heightCm,
      "fixedDesi": fixedDesi,

      "shippingMode": shippingMode,
      "shippingPayer": shippingPayer,
      "originCity": originCity,

      "shippingProfile": shippingProfile,
      "taxIncluded": taxIncluded,

      "preparationDays": preparationDays,
      "maxDeliveryDays": maxDeliveryDays,

      "allowFreeShipping": allowFreeShipping,

      "isShippable": isShippable,
      "deliveryType": deliveryType,

      "allowPickup": allowPickup,
      "allowSameDay": allowSameDay,

      "isFragile": isFragile,
      "isPerishable": isPerishable,
      "isOversize": isOversize,

      "allowReturns": allowReturns,
      "returnWindowDays": returnWindowDays,

      "businessName": businessName,
      "businessLogo": businessLogo,

      "returnShippingPayer": returnShippingPayer,
      "hasContractedReturnCarrier": hasContractedReturnCarrier,
      "returnCarrierCode": returnCarrierCode,

      "allowedCarrierCodes": allowedCarrierCodes,
      "excludedCities": excludedCities,

      "currency": currency,

      "media": media.map((e) => e.toJson()).toList(),

      "stock": stock,
      "minStock": minStock,

      "category": category,
      "brand": brand,

      "barcode": barcode,
      "sku": sku,

      "isActive": isActive,

      "shippingSnapshot": shippingSnapshot,

      // 🔥 timestamps
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }

  // =====================================================
  // 🔥 BACKWARD COMPATIBILITY
  // =====================================================
  List<String> get images {
    return media
        .map((m) {
          if (m.type == 'video') {
            return m.thumbnailUrl ?? '';
          }
          return m.originalUrl;
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // =====================================================
  // 🔥 BUSINESS LOGIC
  // =====================================================

  bool get isLowStock {
    if (minStock == null) return stock < 5;
    return stock < minStock!;
  }

  int get discountPercent {
    if (salePrice == null || salePrice! >= price) return 0;
    return ((1 - (salePrice! / price)) * 100).round();
  }

  double getWholesaleOrRetail(bool isBusinessUser) {
    if (isBusinessUser && wholesalePrice != null) {
      return wholesalePrice!;
    }
    return finalPrice;
  }

  bool isFreeShipping(double cartTotal) {
    if (freeShippingThreshold == null) return false;
    return cartTotal >= freeShippingThreshold!;
  }

  double getShippingCost(double cartTotal) {
    if (isFreeShipping(cartTotal)) return 0;
    return shippingFee ?? 0;
  }

  bool get requiresShippingDimensions {
    return isShippable && deliveryType == 'cargo';
  }

  bool get hasValidShippingSize {
    if (!requiresShippingDimensions) return true;
    if (fixedDesi != null && fixedDesi! > 0) return true;

    return weightKg != null &&
        weightKg! > 0 &&
        lengthCm != null &&
        lengthCm! > 0 &&
        widthCm != null &&
        widthCm! > 0 &&
        heightCm != null &&
        heightCm! > 0;
  }

  double get volumetricDesi {
    if (fixedDesi != null && fixedDesi! > 0) return fixedDesi!;
    if (lengthCm == null || widthCm == null || heightCm == null) return 0;
    return (lengthCm! * widthCm! * heightCm!) / 3000;
  }

  factory Product.empty(String id) {
    return Product(
      id: id,
      businessId: '',
      name: '',
      description: '',
      price: 0,
      currency: 'TRY', // 🔥 خیلی مهم
      media: [],
      stock: 0,
      category: 'general',
      isActive: true,
    );
  }
}
