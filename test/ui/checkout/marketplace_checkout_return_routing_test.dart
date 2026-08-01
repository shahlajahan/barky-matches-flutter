import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/checkout/marketplace_checkout_return_routing.dart';

void main() {
  test('websub_-prefixed order ids belong to Web subscription orders', () {
    expect(isWebSubscriptionOrderId('websub_abc123_premium_12345'), isTrue);
  });

  test('Firestore auto-id marketplace orders are not subscription orders', () {
    expect(isWebSubscriptionOrderId('tUZCduoKNrW6i8kwPecO'), isFalse);
  });

  test('empty order id is not a subscription order', () {
    expect(isWebSubscriptionOrderId(''), isFalse);
  });
}
