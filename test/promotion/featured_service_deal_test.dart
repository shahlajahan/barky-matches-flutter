import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/models/featured_deal.dart';

void main() {
  test('promoted service deal renders without requiring a service price', () {
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-1',
      'targetType': 'SERVICE',
      'targetId': 'service/VET/business-1/service-1',
      'sector': 'VET',
      'businessId': 'business-1',
      'serviceId': 'service-1',
      'serviceTitle': 'Laboratory',
      'businessName': 'Vet A',
      'location': 'Kadıköy, Istanbul',
      'price': null,
    });

    expect(deal.isPromotion, isTrue);
    expect(deal.targetType, 'SERVICE');
    expect(deal.targetId, 'service/VET/business-1/service-1');
    expect(deal.serviceTitle, 'Laboratory');
    expect(deal.price, isNull);
  });

  test('promoted service deal retains an optional customer price', () {
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-2',
      'targetType': 'SERVICE',
      'targetId': 'service/GROOMER/business-2/service-2',
      'sector': 'GROOMER',
      'businessId': 'business-2',
      'serviceId': 'service-2',
      'serviceTitle': 'Bath',
      'businessName': 'Groomy B',
      'price': 450,
      'currency': 'TRY',
    });

    expect(deal.price, 450);
    expect(deal.currency, 'TRY');
  });

  test('promoted service preserves an HTTPS logo URL for remote rendering', () {
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-logo',
      'targetType': 'SERVICE',
      'targetId': 'service/VET/business-1/service-1',
      'sector': 'VET',
      'serviceTitle': 'Laboratory',
      'logoUrl': 'https://firebasestorage.googleapis.com/logo.png',
    });

    expect(deal.logoUrl, 'https://firebasestorage.googleapis.com/logo.png');
    expect(promotedFeaturedDealLogoUrl(deal), deal.logoUrl);
    expect(deal.logoAsset, isEmpty);
  });

  test('promoted service prefers displayImageUrl over legacy logoUrl', () {
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-display-image',
      'targetType': 'SERVICE',
      'displayImageUrl': 'https://cdn.test/cover.jpg',
      'logoUrl': 'https://cdn.test/legacy-logo.jpg',
    });

    expect(promotedFeaturedDealLogoUrl(deal), 'https://cdn.test/cover.jpg');
  });

  test('promoted service preserves Firebase download query parameters', () {
    const imageUrl =
        'https://firebasestorage.googleapis.com/v0/b/example/o/cover.jpg'
        '?alt=media&token=redacted-token';
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-query',
      'targetType': 'SERVICE',
      'displayImageUrl': imageUrl,
    });

    final resolved = promotedFeaturedDealLogoUrl(deal);
    final uri = Uri.parse(resolved!);

    expect(resolved, imageUrl);
    expect(uri.queryParameters['alt'], 'media');
    expect(uri.queryParameters['token'], 'redacted-token');
  });

  test('invalid displayImageUrl falls back to a valid legacy logoUrl', () {
    final deal = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-display-image-fallback',
      'targetType': 'SERVICE',
      'displayImageUrl': 'assets/image/logo.png',
      'logoUrl': 'https://cdn.test/legacy-logo.jpg',
    });

    expect(
      promotedFeaturedDealLogoUrl(deal),
      'https://cdn.test/legacy-logo.jpg',
    );
  });

  test('missing or non-HTTPS promoted logo uses the generic fallback path', () {
    final missing = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-missing-logo',
      'targetType': 'SERVICE',
      'targetId': 'service/VET/business-1/service-1',
      'sector': 'VET',
      'serviceTitle': 'Laboratory',
      'logoUrl': null,
    });
    final invalid = FeaturedDeal.fromPromotedService({
      'campaignId': 'campaign-invalid-logo',
      'targetType': 'SERVICE',
      'targetId': 'service/VET/business-1/service-1',
      'sector': 'VET',
      'serviceTitle': 'Laboratory',
      'logoUrl': 'assets/petsupo.png',
    });

    expect(promotedFeaturedDealLogoUrl(missing), isNull);
    expect(promotedFeaturedDealLogoUrl(invalid), isNull);
  });

  test('editorial deals retain their existing asset behavior', () {
    final deal = FeaturedDeal.fromFirestore({
      'title_en': 'Editorial deal',
      'description_en': 'Description',
      'imageUrl': 'assets/brands/editorial.png',
    }, 'en');

    expect(deal.isPromotion, isFalse);
    expect(deal.logoAsset, 'assets/brands/editorial.png');
    expect(promotedFeaturedDealLogoUrl(deal), isNull);
  });

  test('placeholder remains without a remote logo', () {
    final deal = FeaturedDeal.neutralPlaceholder(
      title: 'Featured Deals',
      description: 'Special offers from PetSupo partners will appear here.',
    );

    expect(deal.isPlaceholder, isTrue);
    expect(deal.logoUrl, isNull);
    expect(promotedFeaturedDealLogoUrl(deal), isNull);
  });
}
