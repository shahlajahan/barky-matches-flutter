import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Defined unconditionally by the inline script at the top of web/index.html
// <body>, which normally runs before flutter_bootstrap.js is even fetched —
// but under a stale service worker, an old cached index.html (without this
// global) can be served alongside a new main.dart.js. Never assume it
// exists: check it's present and callable first, and never let this
// diagnostics hook throw and crash the app either way.
@JS('barkyHideStartupStatus')
external JSAny? get _barkyHideStartupStatusRef;

@JS('barkyHideStartupStatus')
external void _hideStartupStatus();

/// Hides the startup safety-net overlay defined in web/index.html. Must
/// only be called once Flutter's first frame has actually rendered — see
/// the addPostFrameCallback in main().
void hideWebStartupStatus() {
  try {
    if (!globalContext.has('barkyHideStartupStatus')) return;
    final ref = _barkyHideStartupStatusRef;
    if (ref == null || !ref.typeofEquals('function')) return;
    _hideStartupStatus();
  } catch (_) {
    // index.html/main.dart.js version mismatch (stale cache) or any other
    // bridge failure — safe no-op, never a NoSuchMethodError.
  }
}
