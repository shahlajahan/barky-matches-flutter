import 'package:barky_matches_fixed/ui/checkout/checkout_completion_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authoritatively paid result claims the order detail exactly once', () {
    final guard = CheckoutCompletionGuard();
    final state = <String, dynamic>{
      'paid': true,
      'cartReconciled': true,
      'sellerOrderIds': ['seller-order-1'],
    };

    expect(guard.claimPaidSellerOrder(state), 'seller-order-1');
    expect(guard.claimPaidSellerOrder(state), isNull);
    expect(guard.handled, isTrue);
  });

  test('pending result does not claim order-detail navigation', () {
    final guard = CheckoutCompletionGuard();

    expect(
      guard.claimPaidSellerOrder(<String, dynamic>{
        'paid': false,
        'cartReconciled': false,
        'sellerOrderIds': ['seller-order-1'],
      }),
      isNull,
    );
    expect(guard.handled, isFalse);
  });

  test('paid result waits until cart reconciliation is complete', () {
    final guard = CheckoutCompletionGuard();

    expect(
      guard.claimPaidSellerOrder(<String, dynamic>{
        'paid': true,
        'cartReconciled': false,
        'sellerOrderIds': ['seller-order-1'],
      }),
      isNull,
    );
    expect(guard.handled, isFalse);
  });
}
