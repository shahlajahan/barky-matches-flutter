import 'diagnostics_report_list_item.dart';
import 'diagnostics_reports_cursor.dart';

class DiagnosticsReportsPage {
  const DiagnosticsReportsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<DiagnosticsReportListItem> items;
  final bool hasMore;
  final DiagnosticsReportsCursor? nextCursor;
}
