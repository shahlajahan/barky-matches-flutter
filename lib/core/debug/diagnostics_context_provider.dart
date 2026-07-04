import 'package:flutter/foundation.dart';

import 'diagnostics_report.dart';

class DiagnosticsContextProvider {
  factory DiagnosticsContextProvider() => _instance;

  DiagnosticsContextProvider._();

  static final DiagnosticsContextProvider _instance =
      DiagnosticsContextProvider._();

  Future<DiagnosticsContext> current() async {
    return DiagnosticsContext(
      appVersion: 'unknown',
      buildNumber: 'unknown',
      packageName: 'unknown',
      buildMode: _buildMode(),
      platform: defaultTargetPlatform.name,
      deviceModel: 'unknown',
      manufacturer: 'unknown',
      osVersion: 'unknown',
      locale: 'unknown',
      timezone: 'unknown',
      userId: 'anonymous',
      isGuest: true,
      language: 'unknown',
      currentRoute: 'unknown',
      currentFeature: 'unknown',
    );
  }

  String _buildMode() {
    if (kReleaseMode) {
      return 'release';
    }

    if (kProfileMode) {
      return 'profile';
    }

    return 'debug';
  }
}

class DiagnosticsContext {
  const DiagnosticsContext({
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    required this.buildMode,
    required this.platform,
    required this.deviceModel,
    required this.manufacturer,
    required this.osVersion,
    required this.locale,
    required this.timezone,
    required this.userId,
    required this.isGuest,
    required this.language,
    required this.currentRoute,
    required this.currentFeature,
  });

  final String appVersion;
  final String buildNumber;
  final String packageName;
  final String buildMode;
  final String platform;
  final String deviceModel;
  final String manufacturer;
  final String osVersion;
  final String locale;
  final String timezone;
  final String userId;
  final bool isGuest;
  final String language;
  final String currentRoute;
  final String currentFeature;

  DiagnosticsAppInfo get app => DiagnosticsAppInfo(
        version: appVersion,
        buildNumber: buildNumber,
        buildMode: buildMode,
        packageName: packageName,
      );

  DiagnosticsDeviceInfo get device => DiagnosticsDeviceInfo(
        platform: platform,
        manufacturer: manufacturer,
        model: deviceModel,
        osVersion: osVersion,
        locale: locale,
        timezone: timezone,
      );

  DiagnosticsUserInfo get user => DiagnosticsUserInfo(
        uid: userId,
        isGuest: isGuest,
        language: language,
      );

  DiagnosticsScreenInfo get screen => DiagnosticsScreenInfo(
        route: currentRoute,
        screenName: currentRoute,
        feature: currentFeature,
      );
}
