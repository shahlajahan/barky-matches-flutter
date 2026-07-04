import 'diagnostics_queue.dart';
import 'diagnostics_report.dart';

class DiagnosticsUploader {
  factory DiagnosticsUploader() => _instance;

  DiagnosticsUploader._();

  static final DiagnosticsUploader _instance = DiagnosticsUploader._();

  final DiagnosticsQueue _queue = DiagnosticsQueue();

  Future<void> uploadPendingReports() async {
    final List<DiagnosticsReport> reports = await _queue.pendingReports();

    for (final DiagnosticsReport report in reports) {
      final bool uploaded = await _uploadReport(report);
      if (uploaded) {
        await _queue.remove(report.clientReportId);
      }
    }
  }

  Future<bool> _uploadReport(DiagnosticsReport report) async {
    return false;
  }
}
