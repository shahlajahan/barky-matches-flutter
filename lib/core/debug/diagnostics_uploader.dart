import 'package:cloud_functions/cloud_functions.dart';

import 'diagnostics_queue.dart';
import 'diagnostics_report.dart';

class DiagnosticsUploader {
  factory DiagnosticsUploader() => _instance;

  DiagnosticsUploader._();

  static final DiagnosticsUploader _instance = DiagnosticsUploader._();
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

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
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'submitDiagnosticsReport',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 15),
        ),
      );

      final HttpsCallableResult<Object?> result = await callable.call(
        report.toMap(),
      );

      final Object? data = result.data;
      if (data is! Map) {
        return false;
      }

      final Object? success = data['success'];
      return success == true;
    } on FirebaseFunctionsException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
