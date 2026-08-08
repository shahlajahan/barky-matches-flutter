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
}
