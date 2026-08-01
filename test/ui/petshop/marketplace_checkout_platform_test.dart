import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/petshop/marketplace_checkout_platform.dart';

void main() {
  test('Web marketplace checkout chooses the browser implementation', () {
    expect(
      marketplaceCheckoutPlatform(isWeb: true),
      MarketplaceCheckoutPlatform.webBrowser,
    );
  });

  test('Android/iOS marketplace checkout chooses the native WebView', () {
    expect(
      marketplaceCheckoutPlatform(isWeb: false),
      MarketplaceCheckoutPlatform.nativeWebView,
    );
  });
}
