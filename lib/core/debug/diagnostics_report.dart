import 'dart:collection';
import 'dart:math';

import 'log_entry.dart';

/// Immutable in-memory diagnostics bundle captured for later delivery.
class DiagnosticsReport {
  factory DiagnosticsReport({
    String? clientReportId,
    String schemaVersion = currentSchemaVersion,
    required String sessionId,
    required DateTime createdAt,
    required String reason,
    String severity = criticalSeverity,
    required DiagnosticsAppInfo app,
    required DiagnosticsDeviceInfo device,
    required DiagnosticsUserInfo user,
    required DiagnosticsScreenInfo screen,
    required Iterable<LogEntry> logs,
  }) {
    final List<LogEntry> normalizedLogs = List<LogEntry>.unmodifiable(
      logs.map((LogEntry entry) => entry.normalized()),
    );

    return DiagnosticsReport._(
      clientReportId: clientReportId ?? _generateClientReportId(),
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      createdAt: createdAt,
      reason: reason,
      severity: severity,
      app: app,
      device: device,
      user: user,
      screen: screen,
      logCount: normalizedLogs.length,
      logs: UnmodifiableListView<LogEntry>(normalizedLogs),
    );
  }

  factory DiagnosticsReport.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLogs = (map['logs'] as List?) ?? <dynamic>[];
    final List<LogEntry> logs = rawLogs
        .map(
          (dynamic entry) =>
              LogEntry.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);

    return DiagnosticsReport._(
      clientReportId: map['clientReportId'] as String? ?? _generateClientReportId(),
      schemaVersion: map['schemaVersion'] as String? ?? currentSchemaVersion,
      sessionId: map['sessionId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      reason: map['reason'] as String,
      severity: map['severity'] as String? ?? criticalSeverity,
      app: DiagnosticsAppInfo.fromMap(Map<String, dynamic>.from(map['app'] as Map)),
      device: DiagnosticsDeviceInfo.fromMap(
        Map<String, dynamic>.from(map['device'] as Map),
      ),
      user: DiagnosticsUserInfo.fromMap(Map<String, dynamic>.from(map['user'] as Map)),
      screen: DiagnosticsScreenInfo.fromMap(
        Map<String, dynamic>.from(map['screen'] as Map),
      ),
      logCount: map['logCount'] as int? ?? logs.length,
      logs: UnmodifiableListView<LogEntry>(logs),
    );
  }

  factory DiagnosticsReport.fromStorageMap(Map<String, dynamic> map) {
    final Map<String, dynamic> report = Map<String, dynamic>.from(
      map['report'] as Map,
    );

    return DiagnosticsReport.fromMap(<String, dynamic>{
      'clientReportId': map['clientReportId'],
      ...report,
    });
  }

  const DiagnosticsReport._({
    required this.clientReportId,
    required this.schemaVersion,
    required this.sessionId,
    required this.createdAt,
    required this.reason,
    required this.severity,
    required this.app,
    required this.device,
    required this.user,
    required this.screen,
    required this.logCount,
    required this.logs,
  });

  static const String currentSchemaVersion = '1.0';
  static const String criticalSeverity = 'critical';

  final String clientReportId;
  final String schemaVersion;
  final String sessionId;
  final DateTime createdAt;
  final String reason;
  final String severity;
  final DiagnosticsAppInfo app;
  final DiagnosticsDeviceInfo device;
  final DiagnosticsUserInfo user;
  final DiagnosticsScreenInfo screen;
  final int logCount;
  final List<LogEntry> logs;

  /// Returns a stable serialized representation for future transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'reason': reason,
      'severity': severity,
      'app': app.toMap(),
      'device': device.toMap(),
      'user': user.toMap(),
      'screen': screen.toMap(),
      'logs': logs.map((LogEntry entry) => entry.toMap()).toList(),
    };
  }

  Map<String, dynamic> toStorageMap() {
    return <String, dynamic>{
      'clientReportId': clientReportId,
      'report': toMap(),
    };
  }

  static String _generateClientReportId() {
    final Random random = Random.secure();
    const String chars = '0123456789abcdef';
    final StringBuffer buffer = StringBuffer(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16),
    );

    for (int index = 0; index < 12; index++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }
}

class DiagnosticsAppInfo {
  const DiagnosticsAppInfo({
    required this.version,
    required this.buildNumber,
    required this.buildMode,
    required this.packageName,
  });

  factory DiagnosticsAppInfo.fromMap(Map<String, dynamic> map) {
    return DiagnosticsAppInfo(
      version: map['version'] as String,
      buildNumber: map['buildNumber'] as String,
      buildMode: map['buildMode'] as String,
      packageName: map['packageName'] as String,
    );
  }

  final String version;
  final String buildNumber;
  final String buildMode;
  final String packageName;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'version': version,
      'buildNumber': buildNumber,
      'buildMode': buildMode,
      'packageName': packageName,
    };
  }
}

class DiagnosticsDeviceInfo {
  const DiagnosticsDeviceInfo({
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.locale,
    required this.timezone,
  });

  factory DiagnosticsDeviceInfo.fromMap(Map<String, dynamic> map) {
    return DiagnosticsDeviceInfo(
      platform: map['platform'] as String,
      manufacturer: map['manufacturer'] as String,
      model: map['model'] as String,
      osVersion: map['osVersion'] as String,
      locale: map['locale'] as String,
      timezone: map['timezone'] as String,
    );
  }

  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final String locale;
  final String timezone;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'platform': platform,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'locale': locale,
      'timezone': timezone,
    };
  }
}

class DiagnosticsUserInfo {
  const DiagnosticsUserInfo({
    required this.uid,
    required this.isGuest,
    required this.language,
  });

  factory DiagnosticsUserInfo.fromMap(Map<String, dynamic> map) {
    return DiagnosticsUserInfo(
      uid: map['uid'] as String,
      isGuest: map['isGuest'] as bool,
      language: map['language'] as String,
    );
  }

  final String uid;
  final bool isGuest;
  final String language;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'isGuest': isGuest,
      'language': language,
    };
  }
}

class DiagnosticsScreenInfo {
  const DiagnosticsScreenInfo({
    required this.route,
    required this.screenName,
    required this.feature,
  });

  factory DiagnosticsScreenInfo.fromMap(Map<String, dynamic> map) {
    return DiagnosticsScreenInfo(
      route: map['route'] as String,
      screenName: map['screenName'] as String,
      feature: map['feature'] as String,
    );
  }

  final String route;
  final String screenName;
  final String feature;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'route': route,
      'screenName': screenName,
      'feature': feature,
    };
  }
}
