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

  test('claims every unique seller order in original order', () {
    final guard = CheckoutCompletionGuard();

    expect(
      guard.claimPaidSellerOrders(<String, dynamic>{
        'paid': true,
        'cartReconciled': true,
        'sellerOrderIds': [
          'seller-order-2',
          null,
          '',
          ' seller-order-1 ',
          'seller-order-2',
        ],
      }),
      ['seller-order-2', 'seller-order-1'],
    );
    expect(guard.claimPaidSellerOrders(null), isEmpty);
    expect(guard.handled, isTrue);
  });

  test('supports legacy singular sellerOrderId response', () {
    final guard = CheckoutCompletionGuard();

    expect(
      guard.claimPaidSellerOrders(<String, dynamic>{
        'paid': true,
        'cartReconciled': true,
        'sellerOrderId': 'legacy-seller-order',
      }),
      ['legacy-seller-order'],
    );
  });

  test('invalid ids do not consume the completion guard', () {
    final guard = CheckoutCompletionGuard();

    expect(
      guard.claimPaidSellerOrders(<String, dynamic>{
        'paid': true,
        'cartReconciled': true,
        'sellerOrderIds': [null, '  '],
      }),
      isEmpty,
    );
    expect(guard.handled, isFalse);
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
