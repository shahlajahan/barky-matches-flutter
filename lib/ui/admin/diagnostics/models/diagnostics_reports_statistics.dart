class DiagnosticsReportsStatistics {
  const DiagnosticsReportsStatistics({
    required this.totalReports,
    required this.openReports,
    required this.resolvedReports,
    required this.ignoredReports,
    required this.criticalReports,
    required this.errorReports,
    required this.warningReports,
  });

  final int totalReports;
  final int openReports;
  final int resolvedReports;
  final int ignoredReports;
  final int criticalReports;
  final int errorReports;
  final int warningReports;
}
