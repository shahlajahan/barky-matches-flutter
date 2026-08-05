import 'dart:html' as html;

Map<String, Object?> webRedirectDiagnosticSnapshot() {
  bool containsRedirectState(Iterable<String> keys) {
    return keys.any((key) => key.contains('social_auth.pending_redirect'));
  }

  return {
    'href': html.window.location.href,
    'origin': html.window.location.origin,
    'pathname': html.window.location.pathname,
    'search': html.window.location.search,
    'hash': html.window.location.hash,
    'referrer': html.document.referrer,
    'userAgent': html.window.navigator.userAgent,
    'sessionStorageHasRedirectState': containsRedirectState(
      html.window.sessionStorage.keys,
    ),
    'localStorageHasRedirectState': containsRedirectState(
      html.window.localStorage.keys,
    ),
  };
}

bool get isMobileSafariWeb {
  final navigator = html.window.navigator;
  final userAgent = navigator.userAgent.toLowerCase();
  final platform = (navigator.platform ?? '').toLowerCase();
  final safari =
      userAgent.contains('safari') &&
      !userAgent.contains('chrome') &&
      !userAgent.contains('crios') &&
      !userAgent.contains('fxios') &&
      !userAgent.contains('edgios');
  final iosDevice =
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
  final ipadDesktopSafari =
      platform.contains('mac') &&
      userAgent.contains('macintosh') &&
      (navigator.maxTouchPoints ?? 0) > 1;
  return safari && (iosDevice || ipadDesktopSafari);
}
