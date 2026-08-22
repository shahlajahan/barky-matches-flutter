import 'dart:async';

import 'package:barky_matches_fixed/services/mobile_advertising_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeMobileAdvertisingPlatform implements MobileAdvertisingPlatform {
  _FakeMobileAdvertisingPlatform({
    this.supported = true,
    this.canRequest = true,
    this.privacyStatus = PrivacyOptionsRequirementStatus.notRequired,
    this.failConsentUpdateCount = 0,
    this.failConsentForm = false,
    this.failInitializeCount = 0,
    this.consentUpdateCompleter,
    this.initializeCompleter,
  });

  final bool supported;
  bool canRequest;
  PrivacyOptionsRequirementStatus privacyStatus;
  int failConsentUpdateCount;
  final bool failConsentForm;
  int failInitializeCount;
  Completer<void>? consentUpdateCompleter;
  Completer<InitializationStatus>? initializeCompleter;

  int consentUpdates = 0;
  int consentForms = 0;
  int canRequestChecks = 0;
  int privacyStatusChecks = 0;
  int sdkInitializations = 0;
  int privacyOptionsForms = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters parameters,
  ) async {
    consentUpdates += 1;
    final completer = consentUpdateCompleter;
    if (completer != null) await completer.future;
    if (failConsentUpdateCount > 0) {
      failConsentUpdateCount -= 1;
      throw StateError('consent_update_failed');
    }
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    consentForms += 1;
    if (failConsentForm) throw StateError('consent_form_failed');
  }

  @override
  Future<bool> canRequestAds() async {
    canRequestChecks += 1;
    return canRequest;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  privacyOptionsRequirementStatus() async {
    privacyStatusChecks += 1;
    return privacyStatus;
  }

  @override
  Future<InitializationStatus> initializeMobileAds() async {
    sdkInitializations += 1;
    final completer = initializeCompleter;
    if (completer != null) return completer.future;
    if (failInitializeCount > 0) {
      failInitializeCount -= 1;
      throw StateError('sdk_failed');
    }
    return InitializationStatus(const {});
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    privacyOptionsForms += 1;
  }
}

void main() {
  group('MobileAdvertisingService', () {
    Future<void> flushTimers() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'excludes unsupported platforms without contacting UMP or SDK',
      () async {
        final platform = _FakeMobileAdvertisingPlatform(supported: false);
        final service = MobileAdvertisingService(platform: platform);

        final state = await service.initialize();

        expect(state.status, MobileAdvertisingStatus.unavailable);
        expect(state.canRequestAds, isFalse);
        expect(platform.consentUpdates, 0);
        expect(platform.sdkInitializations, 0);
      },
    );

    test('initialization is idempotent', () async {
      final platform = _FakeMobileAdvertisingPlatform();
      final service = MobileAdvertisingService(platform: platform);

      final first = service.initialize();
      final second = service.initialize();
      await Future.wait([first, second]);

      expect(platform.consentUpdates, 1);
      expect(platform.consentForms, 1);
      expect(platform.sdkInitializations, 1);
      expect(service.state.status, MobileAdvertisingStatus.ready);
    });

    test('consent-not-required path allows ads and initializes SDK', () async {
      final platform = _FakeMobileAdvertisingPlatform(
        canRequest: true,
        privacyStatus: PrivacyOptionsRequirementStatus.notRequired,
      );
      final service = MobileAdvertisingService(platform: platform);

      final state = await service.initialize();

      expect(state.status, MobileAdvertisingStatus.ready);
      expect(state.canRequestAds, isTrue);
      expect(state.privacyOptionsRequired, isFalse);
      expect(platform.sdkInitializations, 1);
    });

    test(
      'consent-required path shows form and exposes privacy options',
      () async {
        final platform = _FakeMobileAdvertisingPlatform(
          canRequest: true,
          privacyStatus: PrivacyOptionsRequirementStatus.required,
        );
        final service = MobileAdvertisingService(platform: platform);

        final state = await service.initialize();

        expect(platform.consentForms, 1);
        expect(state.status, MobileAdvertisingStatus.ready);
        expect(state.privacyOptionsRequired, isTrue);
      },
    );

    test('consent failure fails closed and does not initialize SDK', () async {
      final platform = _FakeMobileAdvertisingPlatform(
        failConsentUpdateCount: 1,
      );
      final service = MobileAdvertisingService(
        platform: platform,
        retryDelays: const <Duration>[],
      );

      final state = await service.initialize();

      expect(state.status, MobileAdvertisingStatus.failed);
      expect(state.canRequestAds, isFalse);
      expect(platform.sdkInitializations, 0);
    });

    test(
      'consent form failure fails closed and does not initialize SDK',
      () async {
        final platform = _FakeMobileAdvertisingPlatform(failConsentForm: true);
        final service = MobileAdvertisingService(
          platform: platform,
          retryDelays: const <Duration>[],
        );

        final state = await service.initialize();

        expect(state.status, MobileAdvertisingStatus.failed);
        expect(state.canRequestAds, isFalse);
        expect(platform.sdkInitializations, 0);
      },
    );

    test('SDK initialization failure fails closed', () async {
      final platform = _FakeMobileAdvertisingPlatform(failInitializeCount: 1);
      final service = MobileAdvertisingService(
        platform: platform,
        retryDelays: const <Duration>[],
      );

      final state = await service.initialize();

      expect(state.status, MobileAdvertisingStatus.failed);
      expect(state.canRequestAds, isFalse);
      expect(platform.sdkInitializations, 1);
    });

    test('temporary UMP update failure recovers on bounded retry', () async {
      final platform = _FakeMobileAdvertisingPlatform(
        failConsentUpdateCount: 1,
      );
      final service = MobileAdvertisingService(
        platform: platform,
        retryDelays: const <Duration>[Duration.zero],
      );

      final first = await service.initialize();
      expect(first.status, MobileAdvertisingStatus.retryScheduled);
      expect(first.canRequestAds, isFalse);
      expect(first.retryAttempt, 1);
      expect(platform.sdkInitializations, 0);

      await flushTimers();

      expect(service.state.status, MobileAdvertisingStatus.ready);
      expect(service.canRequestAds, isTrue);
      expect(platform.consentUpdates, 2);
      expect(platform.sdkInitializations, 1);
    });

    test('SDK initialization failure recovers on bounded retry', () async {
      final platform = _FakeMobileAdvertisingPlatform(failInitializeCount: 1);
      final service = MobileAdvertisingService(
        platform: platform,
        retryDelays: const <Duration>[Duration.zero],
      );

      final first = await service.initialize();
      expect(first.status, MobileAdvertisingStatus.retryScheduled);

      await flushTimers();

      expect(service.state.status, MobileAdvertisingStatus.ready);
      expect(platform.sdkInitializations, 2);
    });

    test(
      'timeout followed by bounded recovery ignores stale completion',
      () async {
        final initializeCompleter = Completer<InitializationStatus>();
        final platform = _FakeMobileAdvertisingPlatform(
          initializeCompleter: initializeCompleter,
        );
        final service = MobileAdvertisingService(
          platform: platform,
          startupTimeout: Duration.zero,
          retryDelays: const <Duration>[Duration.zero],
        );

        final first = await service.initialize();
        expect(first.status, MobileAdvertisingStatus.retryScheduled);
        expect(first.message, 'mobile_ads_startup_timeout');

        platform.initializeCompleter = null;
        await flushTimers();
        expect(service.state.status, MobileAdvertisingStatus.ready);

        initializeCompleter.complete(InitializationStatus(const {}));
        await flushTimers();

        expect(service.state.status, MobileAdvertisingStatus.ready);
        expect(platform.sdkInitializations, 2);
      },
    );

    test('does not retry when consent disallows ads', () async {
      final platform = _FakeMobileAdvertisingPlatform(canRequest: false);
      final service = MobileAdvertisingService(
        platform: platform,
        retryDelays: const <Duration>[Duration.zero],
      );

      final state = await service.initialize();
      await flushTimers();

      expect(state.status, MobileAdvertisingStatus.adsNotAllowed);
      expect(service.state.status, MobileAdvertisingStatus.adsNotAllowed);
      expect(platform.consentUpdates, 1);
      expect(platform.sdkInitializations, 0);
    });

    test(
      'multiple callers do not create multiple initialization attempts',
      () async {
        final consentCompleter = Completer<void>();
        final platform = _FakeMobileAdvertisingPlatform(
          consentUpdateCompleter: consentCompleter,
        );
        final service = MobileAdvertisingService(platform: platform);

        final attempts = List<Future<MobileAdvertisingState>>.generate(
          5,
          (_) => service.initialize(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(platform.consentUpdates, 1);

        consentCompleter.complete();
        await Future.wait(attempts);

        expect(platform.consentUpdates, 1);
        expect(platform.sdkInitializations, 1);
        expect(service.state.status, MobileAdvertisingStatus.ready);
      },
    );

    test(
      'retry limit reached remains failed and does not retry forever',
      () async {
        final platform = _FakeMobileAdvertisingPlatform(
          failConsentUpdateCount: 3,
        );
        final service = MobileAdvertisingService(
          platform: platform,
          retryDelays: const <Duration>[Duration.zero, Duration.zero],
        );

        await service.initialize();
        await flushTimers();
        await flushTimers();

        expect(service.state.status, MobileAdvertisingStatus.failed);
        expect(service.state.message, 'mobile_ads_retry_limit_reached');
        expect(service.state.retryAttempt, 2);
        expect(platform.consentUpdates, 3);
        expect(platform.sdkInitializations, 0);
      },
    );

    test('ads-cannot-be-requested path does not initialize SDK', () async {
      final platform = _FakeMobileAdvertisingPlatform(canRequest: false);
      final service = MobileAdvertisingService(platform: platform);

      final state = await service.initialize();

      expect(state.status, MobileAdvertisingStatus.adsNotAllowed);
      expect(state.canRequestAds, isFalse);
      expect(platform.sdkInitializations, 0);
    });

    test('privacy options form refreshes ad request state', () async {
      final platform = _FakeMobileAdvertisingPlatform(
        canRequest: true,
        privacyStatus: PrivacyOptionsRequirementStatus.required,
      );
      final service = MobileAdvertisingService(platform: platform);
      await service.initialize();

      platform.canRequest = false;
      await service.openPrivacyOptions();

      expect(platform.privacyOptionsForms, 1);
      expect(service.state.status, MobileAdvertisingStatus.adsNotAllowed);
      expect(service.canRequestAds, isFalse);
    });
  });
}
