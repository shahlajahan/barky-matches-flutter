class PromotionFeaturedDealRefreshPolicy {
  const PromotionFeaturedDealRefreshPolicy._();

  static const clientTtl = Duration(minutes: 5);

  static bool isStale({DateTime? lastFetchedAt, required DateTime now}) {
    if (lastFetchedAt == null) return true;
    return now.difference(lastFetchedAt) >= clientTtl;
  }
}
