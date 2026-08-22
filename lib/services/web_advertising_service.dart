import 'package:flutter/foundation.dart';

import 'web_advertising_platform.dart';
import 'web_advertising_platform_stub.dart'
    if (dart.library.html) 'web_advertising_platform_web.dart';

enum WebAdConsentStatus { unknown, granted, denied }

enum WebAdLifecycleEvent {
  consentBlocked,
  entitlementSuppressed,
  configurationBlocked,
  debugPlaceholder,
  scriptRequested,
  scriptLoaded,
  slotRequested,
  rendered,
  noFillOrError,
  duplicatePrevented,
  disposed,
}

@immutable
class WebAdConfiguration {
  const WebAdConfiguration({
    required this.enabled,
    required this.publisherId,
    required this.slotIds,
    this.scriptBaseUri =
        'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
    this.approvedHosts = const <String>{'app.petsupo.com'},
  });

  factory WebAdConfiguration.fromEnvironment() {
    const enabled = bool.fromEnvironment('PETSUPO_WEB_ADS_ENABLED');
    const publisherId = String.fromEnvironment('PETSUPO_WEB_ADS_PUBLISHER_ID');
    const homeFooterSlot = String.fromEnvironment(
      'PETSUPO_WEB_ADS_HOME_FOOTER_SLOT',
    );

    return WebAdConfiguration(
      enabled: enabled,
      publisherId: publisherId,
      slotIds: <String, String>{
        if (homeFooterSlot.isNotEmpty) 'home_footer_banner': homeFooterSlot,
      },
    );
  }

  factory WebAdConfiguration.disabled() {
    return const WebAdConfiguration(
      enabled: false,
      publisherId: '',
      slotIds: <String, String>{},
    );
  }

  final bool enabled;
  final String publisherId;
  final Map<String, String> slotIds;
  final String scriptBaseUri;
  final Set<String> approvedHosts;

  bool get hasWebPublisherId =>
      RegExp(r'^ca-pub-\d{16}$').hasMatch(publisherId);

  bool hasSlot(String placementKey) {
    final slotId = slotIds[placementKey];
    return slotId != null && RegExp(r'^\d{6,}$').hasMatch(slotId);
  }

  bool get isProductionReady => enabled && hasWebPublisherId;

  Uri scriptUri() {
    return Uri.parse(
      scriptBaseUri,
    ).replace(queryParameters: <String, String>{'client': publisherId});
  }
}

@immutable
class WebAdDecision {
  const WebAdDecision._({
    required this.mayRequest,
    required this.showPlaceholder,
    required this.reserveSpace,
    required this.reason,
  });

  const WebAdDecision.request()
    : this._(
        mayRequest: true,
        showPlaceholder: false,
        reserveSpace: true,
        reason: 'request_allowed',
      );

  const WebAdDecision.placeholder()
    : this._(
        mayRequest: false,
        showPlaceholder: true,
        reserveSpace: true,
        reason: 'debug_placeholder',
      );

  const WebAdDecision.suppressed(String reason)
    : this._(
        mayRequest: false,
        showPlaceholder: false,
        reserveSpace: false,
        reason: reason,
      );

  final bool mayRequest;
  final bool showPlaceholder;
  final bool reserveSpace;
  final String reason;
}

class WebAdvertisingService extends ChangeNotifier {
  WebAdvertisingService({
    WebAdConfiguration? configuration,
    WebAdvertisingPlatform platform = const DefaultWebAdvertisingPlatform(),
    bool productionRequestsAllowed = kReleaseMode,
  }) : _configuration = configuration ?? WebAdConfiguration.fromEnvironment(),
       _platform = platform,
       _productionRequestsAllowed = productionRequestsAllowed;

  static final WebAdvertisingService instance = WebAdvertisingService();

  final WebAdConfiguration _configuration;
  final WebAdvertisingPlatform _platform;
  final bool _productionRequestsAllowed;
  final Set<String> _activeSlots = <String>{};
  final List<WebAdLifecycleEvent> _events = <WebAdLifecycleEvent>[];
  Future<void>? _scriptLoad;
  WebAdConsentStatus _consentStatus = WebAdConsentStatus.unknown;

  WebAdConfiguration get configuration => _configuration;
  WebAdConsentStatus get consentStatus => _consentStatus;
  List<WebAdLifecycleEvent> get events =>
      List<WebAdLifecycleEvent>.unmodifiable(_events);

  void updateConsent(WebAdConsentStatus status) {
    if (_consentStatus == status) return;
    _consentStatus = status;
    notifyListeners();
  }

  WebAdDecision decisionFor({
    required String placementKey,
    required bool shouldShowAds,
  }) {
    if (!_platform.isSupported) {
      _record(WebAdLifecycleEvent.configurationBlocked, 'unsupported_platform');
      return const WebAdDecision.suppressed('unsupported_platform');
    }
    if (!_configuration.isProductionReady ||
        !_configuration.hasSlot(placementKey)) {
      _record(
        WebAdLifecycleEvent.configurationBlocked,
        'missing_web_ads_configuration',
      );
      return const WebAdDecision.suppressed('missing_web_ads_configuration');
    }
    if (!shouldShowAds) {
      _record(
        WebAdLifecycleEvent.entitlementSuppressed,
        'paid_or_suppressed_user',
      );
      return const WebAdDecision.suppressed('paid_or_suppressed_user');
    }
    if (_consentStatus != WebAdConsentStatus.granted) {
      _record(WebAdLifecycleEvent.consentBlocked, _consentStatus.name);
      return WebAdDecision.suppressed('consent_${_consentStatus.name}');
    }
    if (!_productionRequestsAllowed || _platform.isLocalDebugHost) {
      _record(WebAdLifecycleEvent.debugPlaceholder, placementKey);
      return const WebAdDecision.placeholder();
    }
    if (!_configuration.approvedHosts.contains(_platform.currentHost)) {
      _record(WebAdLifecycleEvent.configurationBlocked, 'unapproved_host');
      return const WebAdDecision.suppressed('unapproved_host');
    }
    return const WebAdDecision.request();
  }

  Future<WebAdDecision> requestSlot({
    required String placementKey,
    required String elementId,
    required bool shouldShowAds,
  }) async {
    final decision = decisionFor(
      placementKey: placementKey,
      shouldShowAds: shouldShowAds,
    );
    if (!decision.mayRequest) return decision;

    if (!_activeSlots.add(elementId)) {
      _record(WebAdLifecycleEvent.duplicatePrevented, elementId);
      return const WebAdDecision.suppressed('duplicate_slot');
    }

    try {
      _record(WebAdLifecycleEvent.scriptRequested, placementKey);
      _scriptLoad ??= _platform.loadScriptOnce(
        scriptId: 'petsupo-adsense-script',
        scriptUri: _configuration.scriptUri(),
      );
      await _scriptLoad;
      _record(WebAdLifecycleEvent.scriptLoaded, placementKey);
      _record(WebAdLifecycleEvent.slotRequested, placementKey);
      await _platform.requestSlot(
        elementId: elementId,
        publisherId: _configuration.publisherId,
        slotId: _configuration.slotIds[placementKey]!,
      );
      _record(WebAdLifecycleEvent.rendered, placementKey);
      return decision;
    } catch (_) {
      _activeSlots.remove(elementId);
      _record(WebAdLifecycleEvent.noFillOrError, placementKey);
      return const WebAdDecision.suppressed('slot_error');
    }
  }

  void disposeSlot(String elementId) {
    if (_activeSlots.remove(elementId)) {
      _platform.disposeSlot(elementId);
      _record(WebAdLifecycleEvent.disposed, elementId);
    }
  }

  void _record(WebAdLifecycleEvent event, String detail) {
    _events.add(event);
    debugPrint('[WebAds] ${event.name} detail=$detail');
  }
}
