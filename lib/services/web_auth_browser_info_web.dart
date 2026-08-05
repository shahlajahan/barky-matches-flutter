import 'dart:html' as html;

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
