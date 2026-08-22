// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'web_advertising_platform.dart';

class DefaultWebAdvertisingPlatform implements WebAdvertisingPlatform {
  const DefaultWebAdvertisingPlatform();

  static final Map<String, Future<void>> _scriptLoads =
      <String, Future<void>>{};

  @override
  bool get isSupported => true;

  @override
  String get currentHost => html.window.location.hostname ?? '';

  @override
  bool get isLocalDebugHost {
    final host = currentHost.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  @override
  Future<void> loadScriptOnce({
    required String scriptId,
    required Uri scriptUri,
  }) {
    final existing = html.document.getElementById(scriptId);
    if (existing != null) {
      return _scriptLoads.putIfAbsent(scriptId, () async {});
    }

    return _scriptLoads.putIfAbsent(scriptId, () {
      final completer = Completer<void>();
      final script = html.ScriptElement()
        ..id = scriptId
        ..async = true
        ..src = scriptUri.toString()
        ..crossOrigin = 'anonymous';

      script.onLoad.first.then((_) => completer.complete());
      script.onError.first.then(
        (_) => completer.completeError(StateError('web_ad_script_load_failed')),
      );
      html.document.head?.append(script);
      return completer.future;
    });
  }

  @override
  Future<void> requestSlot({
    required String elementId,
    required String publisherId,
    required String slotId,
  }) async {
    // The production DOM renderer is intentionally not active until a real
    // AdSense site approval, web ad unit, and CMP are configured.
    throw UnsupportedError('web_ad_slot_renderer_not_configured');
  }

  @override
  void disposeSlot(String elementId) {
    html.document.getElementById(elementId)?.remove();
  }
}
