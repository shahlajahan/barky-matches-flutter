import 'package:barky_matches_fixed/services/pre_shipment_cancellation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid, confirmed, and preparing orders can be cancelled', () {
    expect(isPreShipmentCancellationEligible('paid'), isTrue);
    expect(isPreShipmentCancellationEligible('confirmed'), isTrue);
    expect(isPreShipmentCancellationEligible('preparing'), isTrue);
  });

  test('shipped, delivered, return, cancelled, and refunded cannot cancel', () {
    for (final status in [
      'shipped',
      'delivered',
      'return_pending',
      'cancelled',
      'refunded',
    ]) {
      expect(
        isPreShipmentCancellationEligible(status),
        isFalse,
        reason: status,
      );
    }
  });

  test('a shipment timestamp overrides an otherwise eligible status', () {
    expect(
      isPreShipmentCancellationEligible('preparing', shipmentStarted: true),
      isFalse,
    );
  });
}
