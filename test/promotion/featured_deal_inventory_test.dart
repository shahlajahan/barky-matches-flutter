import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/models/featured_deal.dart';
import 'package:barky_matches_fixed/promotion/services/featured_deal_inventory.dart';

FeaturedDeal promoted(String campaignId) {
  return FeaturedDeal.fromPromotedService({
    'campaignId': campaignId,
    'targetType': 'SERVICE',
    'targetId': 'service/VET/business-1/service-1',
    'sector': 'VET',
    'businessId': 'business-1',
    'serviceId': 'service-1',
    'serviceTitle': 'Laboratory',
    'businessName': 'Vet A',
  });
}

void main() {
  final placeholder = FeaturedDeal.neutralPlaceholder(
    title: 'Featured Deals',
    description: 'Special offers from PetSupo partners will appear here.',
  );

  test('zero real inventory returns a neutral non-promotional placeholder', () {
    final inventory = composeFeaturedDealInventory(
      editorialDeals: const [],
      promotedDeals: const [],
      placeholder: placeholder,
    );

    expect(inventory, hasLength(1));
    expect(inventory.single.isPlaceholder, isTrue);
    expect(inventory.single.isPromotion, isFalse);
    expect(inventory.single.discountPercent, 0);
    expect(inventory.single.shopName, 'Featured Deals');
    expect(inventory.single.description, contains('PetSupo partners'));
    expect(inventory.single.logoAsset, isEmpty);
  });

  test('a real promotion replaces the placeholder and stays attributable', () {
    final deal = promoted('campaign-1');
    final inventory = composeFeaturedDealInventory(
      editorialDeals: const [],
      promotedDeals: [deal],
      placeholder: placeholder,
    );

    expect(inventory, [deal]);
    expect(inventory.any((item) => item.isPlaceholder), isFalse);
    expect(inventory.single.isPromotion, isTrue);
    expect(inventory.single.campaignId, 'campaign-1');
  });

  test('the legacy petshop document is identified as demo-only', () {
    expect(isLegacyDemoFeaturedDealDocument('petshop'), isTrue);
    expect(isLegacyDemoFeaturedDealDocument('real-editorial-deal'), isFalse);
  });

  test('a failed promoted refresh preserves the last valid promotion', () {
    final deal = promoted('campaign-laboratory');
    final inventory = composeFeaturedDealInventory(
      editorialDeals: const [],
      promotedDeals: null,
      previousPromotedDeals: [deal],
      placeholder: placeholder,
    );

    expect(inventory, [deal]);
    expect(inventory.single.campaignId, 'campaign-laboratory');
  });

  test('an empty editorial result cannot erase promoted inventory', () {
    final deal = promoted('campaign-laboratory');
    final inventory = composeFeaturedDealInventory(
      editorialDeals: const [],
      promotedDeals: [deal],
      placeholder: placeholder,
    );

    expect(inventory, [deal]);
    expect(inventory.single.isPromotion, isTrue);
  });
}
