import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buyer cannot view internal seller payout information', () {
    expect(canViewInternalOrderPayout(isSeller: false), isFalse);
  });

  test('seller can view internal payout information', () {
    expect(canViewInternalOrderPayout(isSeller: true), isTrue);
  });
}
