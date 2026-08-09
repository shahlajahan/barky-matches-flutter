import 'package:flutter/foundation.dart';

class PromotionFeaturedDealRefreshPolicy {
  const PromotionFeaturedDealRefreshPolicy._();

  static const clientTtl = Duration(minutes: 5);
  static final ValueNotifier<int> invalidation = ValueNotifier<int>(0);

  /// Forces one best-effort inventory refresh without changing the normal TTL.
  static void invalidate() => invalidation.value++;

  static bool isStale({DateTime? lastFetchedAt, required DateTime now}) {
    if (lastFetchedAt == null) return true;
    return now.difference(lastFetchedAt) >= clientTtl;
  }
}
