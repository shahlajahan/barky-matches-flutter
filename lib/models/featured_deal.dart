class FeaturedDeal {
  final String shopName;

  final String description;

  final int discountPercent;

  final String logoAsset;

  final bool goldOnly;

  final bool premiumOnly;

  final int order;

  const FeaturedDeal({
    required this.shopName,
    required this.description,
    required this.discountPercent,
    required this.logoAsset,
    required this.order,
    this.goldOnly = false,
    this.premiumOnly = false,
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
}
