import '../models/diagnostics_report_detail.dart';
import '../models/diagnostics_reports_page.dart';
import '../models/diagnostics_reports_query.dart';

export '../models/diagnostics_report_detail.dart';
export '../models/diagnostics_report_list_item.dart';
export '../models/diagnostics_report_log_entry.dart';
export '../models/diagnostics_reports_cursor.dart';
export '../models/diagnostics_reports_date_range.dart';
export '../models/diagnostics_reports_page.dart';
export '../models/diagnostics_reports_query.dart';

abstract class DiagnosticsReportsRepository {
  Future<DiagnosticsReportsPage> fetchReports(DiagnosticsReportsQuery query);

  Future<DiagnosticsReportDetail?> getReportDetail(String reportId);
}

class FirestoreDiagnosticsReportsRepository
    implements DiagnosticsReportsRepository {
  const FirestoreDiagnosticsReportsRepository();

  @override
  Future<DiagnosticsReportsPage> fetchReports(DiagnosticsReportsQuery query) {
    throw UnimplementedError(
      'Diagnostics reports Firestore queries are implemented in a later commit.',
    );
  }

  @override
  Future<DiagnosticsReportDetail?> getReportDetail(String reportId) {
    throw UnimplementedError(
      'Diagnostics report detail loading is implemented in a later commit.',
    );
  }
}
