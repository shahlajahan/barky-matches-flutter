import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_log.dart';
import 'diagnostics_events.dart';

enum GoogleMapInitializationStage {
  started,
  mapCreated,
  firstCameraMovement,
  ready,
  timeout,
  failure,
}

mixin GoogleMapHealthMonitor<T extends StatefulWidget> on State<T> {
  static const Duration _defaultInitializationTimeout = Duration(seconds: 8);

  Timer? _mapInitializationTimer;
  Stopwatch? _mapInitializationStopwatch;
  String? _mapFeature;
  Map<String, dynamic> _baseMetadata = <String, dynamic>{};
  GoogleMapInitializationStage? _lastStage;
  bool _mapInitializationReported = false;
  bool _mapReady = false;

  void startGoogleMapHealthTimer({
    required String feature,
    Map<String, dynamic>? data,
    Duration timeout = _defaultInitializationTimeout,
  }) {
    _mapFeature = feature;
    _baseMetadata = <String, dynamic>{...?data};
    _lastStage = GoogleMapInitializationStage.started;
    _mapInitializationReported = false;
    _mapReady = false;
    _mapInitializationTimer?.cancel();
    _mapInitializationStopwatch = Stopwatch()..start();

    AppLog.map(
      'Google Map initialization started',
      data: _buildMetadata(
        stage: GoogleMapInitializationStage.started,
        extra: <String, dynamic>{'timeoutMs': timeout.inMilliseconds},
      ),
    );

    _mapInitializationTimer = Timer(timeout, () {
      if (!mounted || _mapReady || _mapInitializationReported) {
        return;
      }

      final GoogleMapInitializationStage? previousStage = _lastStage;
      _mapInitializationReported = true;
      _mapInitializationStopwatch?.stop();
      _mapInitializationTimer = null;
      _lastStage = GoogleMapInitializationStage.timeout;

      unawaited(
        DiagnosticsEvents.mapInitializationFailed(
          message: 'Google Map initialization timed out',
          data: _buildMetadata(
            stage: GoogleMapInitializationStage.timeout,
            previousStage: previousStage,
          ),
        ),
      );
    });
  }

  void trackMapCreated({
    Map<String, dynamic>? data,
  }) {
    _trackStage(
      GoogleMapInitializationStage.mapCreated,
      message: 'Google Map onMapCreated',
      data: data,
    );
  }

  void trackFirstSuccessfulCameraMovement({
    Map<String, dynamic>? data,
  }) {
    _trackStage(
      GoogleMapInitializationStage.firstCameraMovement,
      message: 'Google Map first successful camera movement',
      data: data,
    );
  }

  void completeGoogleMapHealthCheck({
    Map<String, dynamic>? data,
  }) {
    if (_mapReady || _mapInitializationReported) {
      return;
    }

    _mapReady = true;
    _lastStage = GoogleMapInitializationStage.ready;
    _mapInitializationStopwatch?.stop();
    _mapInitializationTimer?.cancel();
    _mapInitializationTimer = null;

    AppLog.map(
      'Google Map ready',
      data: _buildMetadata(
        stage: GoogleMapInitializationStage.ready,
        extra: data,
      ),
    );
  }

  Future<void> reportMapInitializationFailure({
    required Object error,
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    if (_mapReady || _mapInitializationReported) {
      return;
    }

    final GoogleMapInitializationStage? previousStage = _lastStage;
    _mapInitializationReported = true;
    _mapInitializationStopwatch?.stop();
    _mapInitializationTimer?.cancel();
    _mapInitializationTimer = null;
    _lastStage = GoogleMapInitializationStage.failure;

    await DiagnosticsEvents.mapInitializationFailed(
      message: message ?? 'Google Map initialization failed',
      data: _buildMetadata(
        stage: GoogleMapInitializationStage.failure,
        previousStage: previousStage,
        extra: <String, dynamic>{
          ...?data,
          'error': error.toString(),
          if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }

  void cancelGoogleMapHealthTimer() {
    _mapInitializationTimer?.cancel();
    _mapInitializationTimer = null;
    _mapInitializationStopwatch?.stop();
  }

  void _trackStage(
    GoogleMapInitializationStage stage, {
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (_mapReady || _mapInitializationReported) {
      return;
    }

    _lastStage = stage;
    AppLog.map(
      message,
      data: _buildMetadata(stage: stage, extra: data),
    );
  }

  Map<String, dynamic> _buildMetadata({
    required GoogleMapInitializationStage stage,
    GoogleMapInitializationStage? previousStage,
    Map<String, dynamic>? extra,
  }) {
    final Stopwatch? stopwatch = _mapInitializationStopwatch;

    return <String, dynamic>{
      'feature': _mapFeature ?? widget.runtimeType.toString(),
      'stage': stage.name,
      'lastKnownStage': (previousStage ?? _lastStage)?.name,
      'monitorId': identityHashCode(this).toRadixString(16),
      'elapsedMs': stopwatch?.elapsedMilliseconds ?? 0,
      ..._baseMetadata,
      ...?extra,
    };
  }

  @override
  void dispose() {
    cancelGoogleMapHealthTimer();
    super.dispose();
  }
}
