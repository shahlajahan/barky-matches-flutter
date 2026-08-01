// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

Future<void> submitWebSubscriptionCheckout(String checkoutHtml) async {
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

void clearWebSubscriptionReturnQueryParams() {
  final uri = Uri.base;
  if (!uri.queryParameters.containsKey('webSubscriptionReturn') &&
      !uri.queryParameters.containsKey('oid')) {
    return;
  }
  html.window.history.replaceState(null, '', uri.path);
}
