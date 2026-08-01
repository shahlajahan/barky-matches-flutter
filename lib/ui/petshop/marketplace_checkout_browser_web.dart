// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

/// Submits backend-generated İş Bank checkout HTML (hidden fields, Hash V3
/// data — untouched) as a real top-level browser navigation, mirroring the
/// established Web subscription checkout pattern
/// (`web_subscription_browser_web.dart`). A data-URL-style blob avoids
/// popup blockers entirely since no new window/tab is opened — this is a
/// same-tab `location.assign`, not a popup.
Future<void> submitMarketplaceCheckoutHtml(String checkoutHtml) async {
  final bytes = html.Blob([checkoutHtml], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  try {
    html.window.location.assign(url);
  } finally {
    Future<void>.delayed(
      const Duration(seconds: 10),
      () => html.Url.revokeObjectUrl(url),
    );
  }
}

/// Same-tab navigation to an already-hosted checkout URL (e.g. iyzico),
/// used instead of the blob approach when the backend already returned a
/// real URL rather than inline HTML.
Future<void> submitMarketplaceCheckoutUrl(String checkoutUrl) async {
  html.window.location.assign(checkoutUrl);
}

void clearMarketplaceCheckoutReturnQueryParams() {
  final uri = Uri.base;
  if (!uri.queryParameters.containsKey('webSubscriptionReturn') &&
      !uri.queryParameters.containsKey('oid')) {
    return;
  }
  html.window.history.replaceState(null, '', uri.path);
}
