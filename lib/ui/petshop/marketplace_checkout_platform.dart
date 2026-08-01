enum MarketplaceCheckoutPlatform { webBrowser, nativeWebView }

/// Pure platform decision for marketplace (Pet Shop) checkout, mirroring
/// `subscriptionCheckoutPlatform` — parameterized on `isWeb` rather than
/// reading `kIsWeb` directly so the routing itself is unit-testable without
/// a browser environment.
MarketplaceCheckoutPlatform marketplaceCheckoutPlatform({required bool isWeb}) {
  return isWeb
      ? MarketplaceCheckoutPlatform.webBrowser
      : MarketplaceCheckoutPlatform.nativeWebView;
}
