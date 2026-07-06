class DiagnosticsReportLogEntry {
  const DiagnosticsReportLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final String? stackTrace;
}
