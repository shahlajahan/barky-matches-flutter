class DiagnosticsReportsCursor {
  const DiagnosticsReportsCursor({
    required this.receivedAt,
    required this.reportId,
    required this.sort,
  });

  final DateTime receivedAt;
  final String reportId;
  final String sort;
}
