import 'diagnostics_report_log_entry.dart';

class DiagnosticsReportDetail {
  const DiagnosticsReportDetail({
    required this.reportId,
    required this.severity,
    required this.reason,
    required this.status,
    required this.receivedAt,
    required this.logs,
    required this.rawJson,
    this.clientReportId,
    this.sessionId,
    this.platform,
    this.version,
    this.buildNumber,
    this.buildMode,
    this.packageName,
    this.manufacturer,
    this.model,
    this.osVersion,
    this.locale,
    this.timezone,
    this.uid,
    this.isGuest,
    this.language,
    this.role,
    this.feature,
    this.screenName,
    this.route,
    this.createdAt,
  });

  final String reportId;
  final String? clientReportId;
  final String? sessionId;
  final String severity;
  final String reason;
  final String status;
  final String? platform;
  final String? version;
  final String? buildNumber;
  final String? buildMode;
  final String? packageName;
  final String? manufacturer;
  final String? model;
  final String? osVersion;
  final String? locale;
  final String? timezone;
  final String? uid;
  final bool? isGuest;
  final String? language;
  final String? role;
  final String? feature;
  final String? screenName;
  final String? route;
  final DateTime receivedAt;
  final DateTime? createdAt;
  final List<DiagnosticsReportLogEntry> logs;
  final Map<String, dynamic> rawJson;
}
