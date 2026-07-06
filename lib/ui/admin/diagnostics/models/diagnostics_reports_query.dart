import 'diagnostics_reports_cursor.dart';
import 'diagnostics_reports_date_range.dart';

enum DiagnosticsReportsSort {
  newestFirst,
  oldestFirst,
}

class DiagnosticsReportsQuery {
  const DiagnosticsReportsQuery({
    this.pageSize = 50,
    this.cursor,
    this.severity,
    this.reason,
    this.feature,
    this.platform,
    this.version,
    this.dateRange,
    this.sort = DiagnosticsReportsSort.newestFirst,
  });

  final int pageSize;
  final DiagnosticsReportsCursor? cursor;
  final String? severity;
  final String? reason;
  final String? feature;
  final String? platform;
  final String? version;
  final DiagnosticsReportsDateRange? dateRange;
  final DiagnosticsReportsSort sort;
}