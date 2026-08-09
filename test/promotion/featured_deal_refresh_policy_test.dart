import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_featured_deal_refresh_policy.dart';

void main() {
  test('Featured Deal client refresh uses a five-minute TTL', () {
    final now = DateTime(2026, 8, 8, 10);
    expect(PromotionFeaturedDealRefreshPolicy.isStale(now: now), isTrue);
    expect(
      PromotionFeaturedDealRefreshPolicy.isStale(
        lastFetchedAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
        now: now,
      ),
      isFalse,
    );
    expect(
      PromotionFeaturedDealRefreshPolicy.isStale(
        lastFetchedAt: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isTrue,
    );
  });

  test('successful activation invalidates one cached inventory refresh', () {
    final before = PromotionFeaturedDealRefreshPolicy.invalidation.value;
    PromotionFeaturedDealRefreshPolicy.invalidate();
    expect(PromotionFeaturedDealRefreshPolicy.invalidation.value, before + 1);
  });
}
