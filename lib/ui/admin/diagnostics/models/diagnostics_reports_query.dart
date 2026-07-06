import 'diagnostics_reports_cursor.dart';
import 'diagnostics_reports_date_range.dart';

const Object _diagnosticsReportsQueryUnset = Object();

enum DiagnosticsReportsSort { newestFirst, oldestFirst }

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

  DiagnosticsReportsQuery copyWith({
    int? pageSize,
    Object? cursor = _diagnosticsReportsQueryUnset,
    Object? severity = _diagnosticsReportsQueryUnset,
    Object? reason = _diagnosticsReportsQueryUnset,
    Object? feature = _diagnosticsReportsQueryUnset,
    Object? platform = _diagnosticsReportsQueryUnset,
    Object? version = _diagnosticsReportsQueryUnset,
    Object? dateRange = _diagnosticsReportsQueryUnset,
    DiagnosticsReportsSort? sort,
  }) {
    return DiagnosticsReportsQuery(
      pageSize: pageSize ?? this.pageSize,
      cursor: identical(cursor, _diagnosticsReportsQueryUnset)
          ? this.cursor
          : cursor as DiagnosticsReportsCursor?,
      severity: identical(severity, _diagnosticsReportsQueryUnset)
          ? this.severity
          : severity as String?,
      reason: identical(reason, _diagnosticsReportsQueryUnset)
          ? this.reason
          : reason as String?,
      feature: identical(feature, _diagnosticsReportsQueryUnset)
          ? this.feature
          : feature as String?,
      platform: identical(platform, _diagnosticsReportsQueryUnset)
          ? this.platform
          : platform as String?,
      version: identical(version, _diagnosticsReportsQueryUnset)
          ? this.version
          : version as String?,
      dateRange: identical(dateRange, _diagnosticsReportsQueryUnset)
          ? this.dateRange
          : dateRange as DiagnosticsReportsDateRange?,
      sort: sort ?? this.sort,
    );
  }
}
