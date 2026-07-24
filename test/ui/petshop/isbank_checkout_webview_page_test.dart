import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/petshop/isbank_checkout_webview_page.dart';

void main() {
  const orderId = 'order_123';

  test('matches configured success URLs using parsed URI components', () {
    for (final url in [
      'https://app.petsupo.com/isbank/3d-success?oid=$orderId',
      'https://app.petsupo.com/isbank/3d-success/?oid=$orderId',
      'https://barkymatches-new.firebaseapp.com/isbank/3d-success?oid=$orderId',
      'https://isbank3dsuccessreturn-tj6s667gfq-ey.a.run.app/isbank/3d-success?oid=$orderId',
      'https://europe-west3-barkymatches-new.cloudfunctions.net/isbank3DSuccessReturn?oid=$orderId',
      'https://app.petsupo.com/redirect/isbank/3D-SUCCESS?oid=$orderId',
      'https://app.petsupo.com/?webSubscriptionReturn=success&oid=$orderId',
    ]) {
      expect(
        classifyIsbankReturnNavigation(url, expectedOrderId: orderId),
        IsbankReturnNavigation.success,
        reason: url,
      );
    }
  });

  test('matches configured failure URLs using parsed URI components', () {
    for (final url in [
      'https://app.petsupo.com/isbank/3d-fail?oid=$orderId',
      'https://isbank3dfailreturn-tj6s667gfq-ey.a.run.app/isbank/3d-fail/?oid=$orderId',
      'https://app.petsupo.com/?webSubscriptionReturn=fail&oid=$orderId',
    ]) {
      expect(
        classifyIsbankReturnNavigation(url, expectedOrderId: orderId),
        IsbankReturnNavigation.failure,
        reason: url,
      );
    }
  });

  test('rejects untrusted hosts', () {
    expect(
      classifyIsbankReturnNavigation(
        'https://example.com/isbank/3d-success?oid=$orderId',
        expectedOrderId: orderId,
      ),
      IsbankReturnNavigation.none,
    );
  });

  test('return oid never becomes local proof of payment', () {
    expect(
      classifyIsbankReturnNavigation(
        'https://app.petsupo.com/isbank/3d-success?oid=normalized-by-bank',
        expectedOrderId: orderId,
      ),
      IsbankReturnNavigation.success,
    );
  });
}
