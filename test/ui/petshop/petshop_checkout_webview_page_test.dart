import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

void main() {
  const orderId = 'order_123';

  test('recognizes canonical PetSupo success callbacks', () {
    for (final url in [
      'https://app.petsupo.com/payment-callback?orderId=$orderId',
      'https://app.petsupo.com/payment-success?orderId=$orderId',
      'https://app.petsupo.com/isbank/3d-success?oid=$orderId',
    ]) {
      expect(
        classifyPetshopReturnNavigation(url, expectedOrderId: orderId),
        PetshopReturnNavigation.success,
        reason: url,
      );
    }
  });

  test('recognizes canonical PetSupo cancellation callbacks', () {
    for (final url in [
      'https://app.petsupo.com/payment-cancel?orderId=$orderId',
      'https://app.petsupo.com/isbank/3d-fail?oid=$orderId',
    ]) {
      expect(
        classifyPetshopReturnNavigation(url, expectedOrderId: orderId),
        PetshopReturnNavigation.failure,
        reason: url,
      );
    }
  });

  test('preserves legacy native success and cancellation links', () {
    expect(
      classifyPetshopReturnNavigation(
        'barkymatches://payment-success?orderId=$orderId',
        expectedOrderId: orderId,
      ),
      PetshopReturnNavigation.success,
    );
    expect(
      classifyPetshopReturnNavigation(
        'barkymatches://payment-cancel?orderId=$orderId',
        expectedOrderId: orderId,
      ),
      PetshopReturnNavigation.failure,
    );
  });

  test('leaves unrelated URLs in the WebView', () {
    expect(
      classifyPetshopReturnNavigation(
        'https://iyzico.com/checkout/form',
        expectedOrderId: orderId,
      ),
      PetshopReturnNavigation.none,
    );
  });

  test(
    'CheckoutPage keeps verification as the post-return source of truth',
    () {
      final source = File(
        'lib/ui/checkout/checkout_page.dart',
      ).readAsStringSync();
      expect(source, contains("httpsCallable('verifyPaymentByOrderId')"));
      expect(source, contains("if (checkoutResult == 'verify')"));
    },
  );
}
