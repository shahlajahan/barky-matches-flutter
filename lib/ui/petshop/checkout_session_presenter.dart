import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';
import 'package:barky_matches_fixed/ui/petshop/isbank_checkout_webview_page.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

Future<String?> presentCheckoutSession({
  required BuildContext context,
  required CheckoutSessionResult session,
  required String orderId,
  required String successUrlPrefix,
  required String cancelUrlPrefix,
}) async {
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
