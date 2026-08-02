// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

/// Same-tab, same-origin navigation to the full Web Creator Dashboard.
/// Deliberately NOT `html.window.open()` (which always opens a new
/// browsing context, per url_launcher_web's implementation) — staying in
/// the current tab means the already-persisted Firebase Auth session
/// (browserLocalPersistence, scoped to this origin) survives the reload,
/// the same way the working İş Bank / Web subscription checkout hand-off
/// already relies on same-tab `location.assign`
/// (web_subscription_browser_web.dart, marketplace_checkout_browser_web.dart).
void openCreatorDashboardSameTab(String url) {
  html.window.location.assign(url);
}
