class DiagnosticsReportListItem {
  const DiagnosticsReportListItem({
    required this.reportId,
    required this.severity,
    required this.reason,
    required this.receivedAt,
    this.clientReportId,
    this.platform,
    this.version,
    this.buildNumber,
    this.feature,
    this.screenName,
    this.route,
    this.uid,
    this.isGuest,
    this.createdAt,
    this.logCount = 0,
  });

  final String reportId;
  final String? clientReportId;
  final String severity;
  final String reason;
  final String? platform;
  final String? version;
  final String? buildNumber;
  final String? feature;
  final String? screenName;
  final String? route;
  final String? uid;
  final bool? isGuest;
  final DateTime receivedAt;
  final DateTime? createdAt;
  final int logCount;
}
