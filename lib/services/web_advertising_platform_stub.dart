import 'web_advertising_platform.dart';

class DefaultWebAdvertisingPlatform implements WebAdvertisingPlatform {
  const DefaultWebAdvertisingPlatform();

  @override
  bool get isSupported => false;

  @override
  String get currentHost => '';

  @override
  bool get isLocalDebugHost => false;

  @override
  Future<void> loadScriptOnce({
    required String scriptId,
    required Uri scriptUri,
  }) async {}

  @override
  Future<void> requestSlot({
    required String elementId,
    required String publisherId,
    required String slotId,
  }) async {}

  @override
  void disposeSlot(String elementId) {}
}
