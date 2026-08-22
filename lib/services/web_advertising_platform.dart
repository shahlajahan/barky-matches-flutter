abstract class WebAdvertisingPlatform {
  bool get isSupported;

  String get currentHost;

  bool get isLocalDebugHost;

  Future<void> loadScriptOnce({
    required String scriptId,
    required Uri scriptUri,
  });

  Future<void> requestSlot({
    required String elementId,
    required String publisherId,
    required String slotId,
  });

  void disposeSlot(String elementId);
}
