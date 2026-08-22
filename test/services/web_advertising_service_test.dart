import 'package:barky_matches_fixed/services/web_advertising_platform.dart';
import 'package:barky_matches_fixed/services/web_advertising_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWebPlatform implements WebAdvertisingPlatform {
  _FakeWebPlatform({
    this.supported = true,
    this.host = 'app.petsupo.com',
    this.localDebugHost = false,
  });

  final bool supported;
  final String host;
  final bool localDebugHost;
  int scriptLoads = 0;
  int slotRequests = 0;
  int disposals = 0;
  final List<Uri> scriptUris = <Uri>[];

  @override
  bool get isSupported => supported;

  @override
  String get currentHost => host;

  @override
  bool get isLocalDebugHost => localDebugHost;

  @override
  Future<void> loadScriptOnce({
    required String scriptId,
    required Uri scriptUri,
  }) async {
    scriptLoads += 1;
    scriptUris.add(scriptUri);
  }

  @override
  Future<void> requestSlot({
    required String elementId,
    required String publisherId,
    required String slotId,
  }) async {
    slotRequests += 1;
  }

  @override
  void disposeSlot(String elementId) {
    disposals += 1;
  }
}

const _readyConfig = WebAdConfiguration(
  enabled: true,
  publisherId: 'ca-pub-1234567890123456',
  slotIds: <String, String>{'home_footer_banner': '1234567890'},
);

void main() {
  group('WebAdvertisingService', () {
    test('mobile or unsupported platforms fail closed', () {
      final service = WebAdvertisingService(
        configuration: _readyConfig,
        platform: _FakeWebPlatform(supported: false),
      );
      service.updateConsent(WebAdConsentStatus.granted);

      final decision = service.decisionFor(
        placementKey: 'home_footer_banner',
        shouldShowAds: true,
      );

      expect(decision.mayRequest, isFalse);
      expect(decision.reserveSpace, isFalse);
      expect(
        service.events,
        contains(WebAdLifecycleEvent.configurationBlocked),
      );
    });

    test('missing AdSense config blocks requests', () {
      final platform = _FakeWebPlatform();
      final service = WebAdvertisingService(
        configuration: WebAdConfiguration.disabled(),
        platform: platform,
      );
      service.updateConsent(WebAdConsentStatus.granted);

      final decision = service.decisionFor(
        placementKey: 'home_footer_banner',
        shouldShowAds: true,
      );

      expect(decision.reason, 'missing_web_ads_configuration');
      expect(decision.reserveSpace, isFalse);
      expect(platform.scriptLoads, 0);
    });

    test('premium, gold, admin, or suppressed users collapse the slot', () {
      final service = WebAdvertisingService(
        configuration: _readyConfig,
        platform: _FakeWebPlatform(),
      );
      service.updateConsent(WebAdConsentStatus.granted);

      final decision = service.decisionFor(
        placementKey: 'home_footer_banner',
        shouldShowAds: false,
      );

      expect(decision.reason, 'paid_or_suppressed_user');
      expect(decision.reserveSpace, isFalse);
      expect(
        service.events,
        contains(WebAdLifecycleEvent.entitlementSuppressed),
      );
    });

    test('consent denial blocks requests before script load', () async {
      final platform = _FakeWebPlatform();
      final service = WebAdvertisingService(
        configuration: _readyConfig,
        platform: platform,
      );
      service.updateConsent(WebAdConsentStatus.denied);

      final decision = await service.requestSlot(
        placementKey: 'home_footer_banner',
        elementId: 'slot-a',
        shouldShowAds: true,
      );

      expect(decision.reason, 'consent_denied');
      expect(platform.scriptLoads, 0);
      expect(platform.slotRequests, 0);
      expect(service.events, contains(WebAdLifecycleEvent.consentBlocked));
    });

    test(
      'debug and localhost render a placeholder without ad requests',
      () async {
        final platform = _FakeWebPlatform(localDebugHost: true);
        final service = WebAdvertisingService(
          configuration: _readyConfig,
          platform: platform,
        );
        service.updateConsent(WebAdConsentStatus.granted);

        final decision = await service.requestSlot(
          placementKey: 'home_footer_banner',
          elementId: 'slot-a',
          shouldShowAds: true,
        );

        expect(decision.showPlaceholder, isTrue);
        expect(decision.reserveSpace, isTrue);
        expect(platform.scriptLoads, 0);
        expect(platform.slotRequests, 0);
        expect(service.events, contains(WebAdLifecycleEvent.debugPlaceholder));
      },
    );

    test('unapproved production hosts fail closed', () {
      final platform = _FakeWebPlatform(host: 'petsupo.com');
      final service = WebAdvertisingService(
        configuration: _readyConfig,
        platform: platform,
        productionRequestsAllowed: true,
      );
      service.updateConsent(WebAdConsentStatus.granted);

      final decision = service.decisionFor(
        placementKey: 'home_footer_banner',
        shouldShowAds: true,
      );

      expect(decision.reason, 'unapproved_host');
      expect(decision.reserveSpace, isFalse);
    });

    test(
      'loads script once and prevents duplicate slot initialization',
      () async {
        final platform = _FakeWebPlatform();
        final service = WebAdvertisingService(
          configuration: _readyConfig,
          platform: platform,
          productionRequestsAllowed: true,
        );
        service.updateConsent(WebAdConsentStatus.granted);

        final first = await service.requestSlot(
          placementKey: 'home_footer_banner',
          elementId: 'slot-a',
          shouldShowAds: true,
        );
        final duplicate = await service.requestSlot(
          placementKey: 'home_footer_banner',
          elementId: 'slot-a',
          shouldShowAds: true,
        );

        expect(first.mayRequest, isTrue);
        expect(duplicate.reason, 'duplicate_slot');
        expect(platform.scriptLoads, 1);
        expect(platform.slotRequests, 1);
        expect(service.events, contains(WebAdLifecycleEvent.scriptLoaded));
        expect(
          service.events,
          contains(WebAdLifecycleEvent.duplicatePrevented),
        );
      },
    );

    test('never accepts mobile AdMob ad unit IDs as web slot IDs', () {
      const config = WebAdConfiguration(
        enabled: true,
        publisherId: 'ca-pub-8741190851877191',
        slotIds: <String, String>{
          'home_footer_banner': 'ca-app-pub-8741190851877191/2113195813',
        },
      );
      final service = WebAdvertisingService(
        configuration: config,
        platform: _FakeWebPlatform(),
      );
      service.updateConsent(WebAdConsentStatus.granted);

      final decision = service.decisionFor(
        placementKey: 'home_footer_banner',
        shouldShowAds: true,
      );

      expect(decision.reason, 'missing_web_ads_configuration');
      expect(decision.reserveSpace, isFalse);
    });
  });
}
