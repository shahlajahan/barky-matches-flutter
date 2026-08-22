import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum MobileAdvertisingStatus {
  notStarted,
  consentUpdating,
  consentFormShowing,
  sdkInitializing,
  retryScheduled,
  ready,
  adsNotAllowed,
  unavailable,
  failed,
}

@immutable
class MobileAdvertisingState {
  const MobileAdvertisingState({
    required this.status,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.retryAttempt = 0,
    this.maxRetryAttempts = 0,
    this.nextRetryDelay,
    this.message,
  });

  const MobileAdvertisingState.notStarted()
    : status = MobileAdvertisingStatus.notStarted,
      canRequestAds = false,
      privacyOptionsRequired = false,
      retryAttempt = 0,
      maxRetryAttempts = 0,
      nextRetryDelay = null,
      message = null;

  final MobileAdvertisingStatus status;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final int retryAttempt;
  final int maxRetryAttempts;
  final Duration? nextRetryDelay;
  final String? message;

  bool get isReady => status == MobileAdvertisingStatus.ready && canRequestAds;

  MobileAdvertisingState copyWith({
    MobileAdvertisingStatus? status,
    bool? canRequestAds,
    bool? privacyOptionsRequired,
    int? retryAttempt,
    int? maxRetryAttempts,
    Duration? nextRetryDelay,
    String? message,
  }) {
    return MobileAdvertisingState(
      status: status ?? this.status,
      canRequestAds: canRequestAds ?? this.canRequestAds,
      privacyOptionsRequired:
          privacyOptionsRequired ?? this.privacyOptionsRequired,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      nextRetryDelay: nextRetryDelay,
      message: message,
    );
  }
}

abstract class MobileAdvertisingPlatform {
  bool get isSupported;

  Future<void> requestConsentInfoUpdate(ConsentRequestParameters parameters);

  Future<void> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<PrivacyOptionsRequirementStatus> privacyOptionsRequirementStatus();

  Future<InitializationStatus> initializeMobileAds();

  Future<void> showPrivacyOptionsForm();
}

class GoogleMobileAdvertisingPlatform implements MobileAdvertisingPlatform {
  const GoogleMobileAdvertisingPlatform();

  @override
  bool get isSupported => !kIsWeb;

  @override
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters parameters,
  ) async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      parameters,
      completer.complete,
      completer.completeError,
    );
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<PrivacyOptionsRequirementStatus> privacyOptionsRequirementStatus() {
    return ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
  }

  @override
  Future<InitializationStatus> initializeMobileAds() {
    return MobileAds.instance.initialize();
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete();
      }
    });
    return completer.future;
  }
}

class MobileAdvertisingService extends ChangeNotifier {
  MobileAdvertisingService({
    MobileAdvertisingPlatform platform =
        const GoogleMobileAdvertisingPlatform(),
    bool debugForceEea = false,
    List<String> debugTestDeviceIds = const <String>[],
    Duration startupTimeout = const Duration(seconds: 8),
    List<Duration> retryDelays = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 8),
      Duration(seconds: 30),
    ],
  }) : _platform = platform,
       _debugForceEea = debugForceEea,
       _debugTestDeviceIds = debugTestDeviceIds,
       _startupTimeout = startupTimeout,
       _retryDelays = retryDelays;

  static final MobileAdvertisingService instance = MobileAdvertisingService();

  final MobileAdvertisingPlatform _platform;
  final bool _debugForceEea;
  final List<String> _debugTestDeviceIds;
  final Duration _startupTimeout;
  final List<Duration> _retryDelays;

  MobileAdvertisingState _state = const MobileAdvertisingState.notStarted();
  Future<MobileAdvertisingState>? _initialization;
  Timer? _retryTimer;
  bool _privacyOptionsFormShowing = false;
  bool _disposed = false;
  int _operationGeneration = 0;
  int _retryAttempt = 0;

  MobileAdvertisingState get state => _state;
  bool get canRequestAds => _state.isReady;
  bool get privacyOptionsRequired => _state.privacyOptionsRequired;

  Future<MobileAdvertisingState> initialize({String source = 'startup'}) {
    if (_initialization != null) return _initialization!;
    if (_state.status == MobileAdvertisingStatus.ready ||
        _state.status == MobileAdvertisingStatus.adsNotAllowed ||
        _state.status == MobileAdvertisingStatus.unavailable ||
        _state.status == MobileAdvertisingStatus.retryScheduled) {
      return Future<MobileAdvertisingState>.value(_state);
    }

    return _startInitialization(source: source);
  }

  Future<MobileAdvertisingState> _startInitialization({
    required String source,
  }) {
    if (_initialization != null) return _initialization!;
    _retryTimer?.cancel();
    _retryTimer = null;
    final generation = ++_operationGeneration;
    _initialization = _initialize(source: source, generation: generation)
        .timeout(
          _startupTimeout,
          onTimeout: () {
            if (!_isCurrentGeneration(generation)) return _state;
            _operationGeneration++;
            _initialization = null;
            _setState(
              MobileAdvertisingState(
                status: MobileAdvertisingStatus.failed,
                canRequestAds: false,
                privacyOptionsRequired: _state.privacyOptionsRequired,
                retryAttempt: _retryAttempt,
                maxRetryAttempts: _retryDelays.length,
                message: 'mobile_ads_startup_timeout',
              ),
            );
            _log('initialization timed out source=$source');
            _scheduleRetry(reason: 'mobile_ads_startup_timeout');
            return _state;
          },
        );
    return _initialization!;
  }

  Future<MobileAdvertisingState> _initialize({
    required String source,
    required int generation,
  }) async {
    if (!_platform.isSupported) {
      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.unavailable,
          canRequestAds: false,
          privacyOptionsRequired: false,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
          message: 'web_or_unsupported_platform',
        ),
      );
      _log('unsupported platform source=$source');
      _initialization = null;
      return _state;
    }

    try {
      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.consentUpdating,
          canRequestAds: false,
          privacyOptionsRequired: false,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
        ),
      );
      _log('consent update started source=$source');
      await _platform.requestConsentInfoUpdate(_consentParameters());
      if (!_isCurrentGeneration(generation)) return _state;
      _log('consent update completed source=$source');

      _setState(
        _state.copyWith(status: MobileAdvertisingStatus.consentFormShowing),
      );
      _log('consent form check started source=$source');
      await _platform.loadAndShowConsentFormIfRequired();
      if (!_isCurrentGeneration(generation)) return _state;
      _log('consent form resolved source=$source');

      final canRequestAds = await _platform.canRequestAds();
      final privacyStatus = await _platform.privacyOptionsRequirementStatus();
      if (!_isCurrentGeneration(generation)) return _state;
      final privacyRequired =
          privacyStatus == PrivacyOptionsRequirementStatus.required;
      _log(
        'privacy options ${privacyRequired ? 'required' : 'not_required'} '
        'source=$source',
      );

      if (!canRequestAds) {
        _setState(
          MobileAdvertisingState(
            status: MobileAdvertisingStatus.adsNotAllowed,
            canRequestAds: false,
            privacyOptionsRequired: privacyRequired,
            retryAttempt: _retryAttempt,
            maxRetryAttempts: _retryDelays.length,
            message: 'consent_does_not_allow_ads',
          ),
        );
        _log('ads cannot be requested source=$source');
        _initialization = null;
        return _state;
      }

      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.sdkInitializing,
          canRequestAds: false,
          privacyOptionsRequired: privacyRequired,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
        ),
      );
      _log('SDK initialization started source=$source');
      await _platform.initializeMobileAds();
      if (!_isCurrentGeneration(generation)) return _state;
      _log('SDK initialization completed source=$source');

      _retryAttempt = 0;
      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.ready,
          canRequestAds: true,
          privacyOptionsRequired: privacyRequired,
          retryAttempt: 0,
          maxRetryAttempts: _retryDelays.length,
        ),
      );
      _initialization = null;
      return _state;
    } catch (error) {
      if (!_isCurrentGeneration(generation)) return _state;
      _initialization = null;
      final safeError = _safeError(error);
      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.failed,
          canRequestAds: false,
          privacyOptionsRequired: _state.privacyOptionsRequired,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
          message: safeError,
        ),
      );
      _log('initialization failed error=$safeError source=$source');
      _scheduleRetry(reason: safeError);
      return _state;
    }
  }

  Future<void> openPrivacyOptions() async {
    if (!_platform.isSupported ||
        !_state.privacyOptionsRequired ||
        _privacyOptionsFormShowing) {
      return;
    }
    _privacyOptionsFormShowing = true;
    try {
      _log('privacy options form opening');
      await _platform.showPrivacyOptionsForm();
      final canRequestAds = await _platform.canRequestAds();
      final privacyStatus = await _platform.privacyOptionsRequirementStatus();
      _setState(
        _state.copyWith(
          status: canRequestAds
              ? MobileAdvertisingStatus.ready
              : MobileAdvertisingStatus.adsNotAllowed,
          canRequestAds: canRequestAds,
          privacyOptionsRequired:
              privacyStatus == PrivacyOptionsRequirementStatus.required,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
        ),
      );
      _log('privacy options form dismissed');
    } catch (error) {
      _log('privacy options form failed error=${_safeError(error)}');
    } finally {
      _privacyOptionsFormShowing = false;
    }
  }

  void _scheduleRetry({required String reason}) {
    if (_state.status == MobileAdvertisingStatus.adsNotAllowed ||
        _state.status == MobileAdvertisingStatus.unavailable ||
        _disposed ||
        _retryTimer != null) {
      return;
    }

    if (_retryAttempt >= _retryDelays.length) {
      _setState(
        MobileAdvertisingState(
          status: MobileAdvertisingStatus.failed,
          canRequestAds: false,
          privacyOptionsRequired: _state.privacyOptionsRequired,
          retryAttempt: _retryAttempt,
          maxRetryAttempts: _retryDelays.length,
          message: 'mobile_ads_retry_limit_reached',
        ),
      );
      _log('retry limit reached reason=$reason');
      return;
    }

    final nextAttempt = _retryAttempt + 1;
    final delay = _retryDelays[_retryAttempt];
    _retryAttempt = nextAttempt;
    _setState(
      MobileAdvertisingState(
        status: MobileAdvertisingStatus.retryScheduled,
        canRequestAds: false,
        privacyOptionsRequired: _state.privacyOptionsRequired,
        retryAttempt: nextAttempt,
        maxRetryAttempts: _retryDelays.length,
        nextRetryDelay: delay,
        message: reason,
      ),
    );
    _log('retry scheduled attempt=$nextAttempt delay=${delay.inSeconds}s');
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_disposed) return;
      unawaited(_startInitialization(source: 'retry_$nextAttempt'));
    });
  }

  ConsentRequestParameters _consentParameters() {
    ConsentDebugSettings? debugSettings;
    if (kDebugMode && (_debugForceEea || _debugTestDeviceIds.isNotEmpty)) {
      debugSettings = ConsentDebugSettings(
        debugGeography: _debugForceEea
            ? DebugGeography.debugGeographyEea
            : DebugGeography.debugGeographyDisabled,
        testIdentifiers: _debugTestDeviceIds.isEmpty
            ? null
            : _debugTestDeviceIds,
      );
    }

    return ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
      consentDebugSettings: debugSettings,
    );
  }

  void _setState(MobileAdvertisingState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  bool _isCurrentGeneration(int generation) {
    return !_disposed && _operationGeneration == generation;
  }

  String _safeError(Object error) {
    if (error is FormError) {
      return 'form_error_${error.errorCode}';
    }
    return error.runtimeType.toString();
  }

  void _log(String message) {
    debugPrint('[MobileAds] $message');
  }

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration++;
    _retryTimer?.cancel();
    _retryTimer = null;
    super.dispose();
  }
}
