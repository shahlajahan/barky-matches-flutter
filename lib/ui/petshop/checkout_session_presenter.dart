import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';
import 'package:barky_matches_fixed/ui/petshop/isbank_checkout_webview_page.dart';
import 'package:barky_matches_fixed/ui/petshop/marketplace_checkout_browser.dart';
import 'package:barky_matches_fixed/ui/petshop/marketplace_checkout_platform.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

Future<String?> presentCheckoutSession({
  required BuildContext context,
  required CheckoutSessionResult session,
  required String orderId,
  required String successUrlPrefix,
  required String cancelUrlPrefix,
}) async {
  // Hard platform boundary: `webview_flutter` is a native Android/iOS
  // implementation. On Web there is no registered WebViewPlatform, so
  // constructing WebViewController() asserts
  // ("WebViewPlatform.instance != null") and crashes the whole checkout.
  // This branch must run — and must return — before either native WebView
  // page is ever pushed.
  if (marketplaceCheckoutPlatform(isWeb: kIsWeb) ==
      MarketplaceCheckoutPlatform.webBrowser) {
    if (session.isIsbank) {
      final html = session.html;
      if (html == null || html.trim().isEmpty) {
        throw StateError('Payment session did not return HTML');
      }
      await submitMarketplaceCheckoutHtml(html);
    } else {
      final checkoutUrl = session.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
        throw StateError('Payment session did not return checkout URL');
      }
      await submitMarketplaceCheckoutUrl(checkoutUrl);
    }
    // The browser is about to navigate away from this document entirely
    // (real top-level navigation, same tab) — this page/isolate will be
    // torn down. Never resolve: the caller must not act on a placeholder
    // result while navigation is in flight. Reconciliation happens on the
    // fresh app load after the bank redirects back — see
    // MarketplaceCheckoutReturnPage / main.dart's payment-return routing.
    return Completer<String?>().future;
  }

  if (session.isIsbank) {
    final html = session.html;
    if (html == null || html.trim().isEmpty) {
      throw StateError('Payment session did not return HTML');
    }

    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => IsbankCheckoutWebViewPage(html: html, orderId: orderId),
      ),
    );
  }

  final checkoutUrl = session.checkoutUrl;
  if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
    throw StateError('Payment session did not return checkout URL');
  }

  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => PetshopCheckoutWebViewPage(
        checkoutUrl: checkoutUrl,
        successUrlPrefix: successUrlPrefix,
        cancelUrlPrefix: cancelUrlPrefix,
        orderId: orderId,
      ),
    ),
  );
}
