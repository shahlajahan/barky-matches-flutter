class FeaturedDeal {
  final String shopName;

  final String description;

  final int discountPercent;

  final String logoAsset;

  final bool goldOnly;

  final bool premiumOnly;

  final int order;

  final String? campaignId;
  final String? targetType;
  final String? targetId;
  final String? sector;
  final String? businessId;
  final String? serviceId;
  final String? serviceTitle;
  final String? businessName;
  final String? location;
  final Object? price;
  final String? currency;
  final String? publicLabel;
  final bool isPromotion;

  const FeaturedDeal({
    required this.shopName,
    required this.description,
    required this.discountPercent,
    required this.logoAsset,
    required this.order,
    this.goldOnly = false,
    this.premiumOnly = false,
    this.campaignId,
    this.targetType,
    this.targetId,
    this.sector,
    this.businessId,
    this.serviceId,
    this.serviceTitle,
    this.businessName,
    this.location,
    this.price,
    this.currency,
    this.publicLabel,
    this.isPromotion = false,
  });

  factory FeaturedDeal.fromFirestore(
    Map<String, dynamic> data,
    String language,
  ) {
    return FeaturedDeal(
      shopName: language == "tr"
          ? data["title_tr"] ?? ""
          : data["title_en"] ?? "",

      description: language == "tr"
          ? data["description_tr"] ?? ""
          : data["description_en"] ?? "",

      discountPercent: (data["discountPercent"] as num?)?.toInt() ?? 0,

      logoAsset: data["imageUrl"] ?? data["logoAsset"] ?? "",

      goldOnly: data["goldOnly"] == true,

      premiumOnly: data["premiumOnly"] == true,

      order: (data["order"] as num?)?.toInt() ?? 0,
    );
  }

  factory FeaturedDeal.fromPromotedService(Map<String, dynamic> data) {
    final serviceTitle = data['serviceTitle']?.toString().trim() ?? '';
    final businessName = data['businessName']?.toString().trim() ?? '';
    final location = data['location']?.toString().trim() ?? '';
    final title = serviceTitle;
    final description = businessName.isNotEmpty
        ? '$businessName${location.isNotEmpty ? ' · $location' : ''}'
        : location;
    return FeaturedDeal(
      shopName: title,
      description: description,
      discountPercent: 0,
      logoAsset: data['logoUrl']?.toString() ?? '',
      order: 0,
      campaignId: data['campaignId']?.toString(),
      targetType: data['targetType']?.toString(),
      targetId: data['targetId']?.toString(),
      sector: data['sector']?.toString().trim().toUpperCase(),
      businessId: data['businessId']?.toString(),
      serviceId: data['serviceId']?.toString(),
      serviceTitle: serviceTitle.isEmpty ? null : serviceTitle,
      businessName: businessName,
      location: location,
      price: data['price'],
      currency: data['currency']?.toString(),
      publicLabel: data['publicLabel']?.toString(),
      isPromotion: true,
    );
  }
}
