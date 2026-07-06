import 'package:flutter/foundation.dart';
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
    debugPrint('[DiagnosticsUploader] upload started');
    final List<DiagnosticsReport> reports = await _queue.pendingReports();
    debugPrint(
      '[DiagnosticsUploader] pending report count: ${reports.length}',
    );

    for (final DiagnosticsReport report in reports) {
      debugPrint(
        '[DiagnosticsUploader] uploading clientReportId: ${report.clientReportId}',
      );
      final bool uploaded = await _uploadReport(report);
      debugPrint(
        '[DiagnosticsUploader] upload ${uploaded ? 'success' : 'failure'} for clientReportId: ${report.clientReportId}',
      );
      if (uploaded) {
        await _queue.remove(report.clientReportId);
        debugPrint(
          '[DiagnosticsUploader] report removed: ${report.clientReportId}',
        );
      }
    }
    debugPrint('[DiagnosticsUploader] upload finished');
  }

  Future<bool> _uploadReport(DiagnosticsReport report) async {
    try {
      debugPrint(
        '[DiagnosticsUploader] callable start for clientReportId: ${report.clientReportId}',
      );
      final HttpsCallable callable = _functions.httpsCallable(
        'submitDiagnosticsReport',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 15),
        ),
      );
      final Map<String, dynamic> payload = report.toMap();
      debugPrint(
        '[DiagnosticsUploader] payload keys: ${payload.keys.toList()}',
      );

      final HttpsCallableResult<Object?> result = await callable.call(
        payload,
      );

      final Object? data = result.data;
      debugPrint('[DiagnosticsUploader] callable response: $data');
      if (data is! Map) {
        return false;
      }

      final Object? success = data['success'];
      return success == true;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[DiagnosticsUploader] FirebaseFunctionsException code: ${error.code}',
      );
      debugPrint(
        '[DiagnosticsUploader] FirebaseFunctionsException message: ${error.message}',
      );
      debugPrint('[DiagnosticsUploader] stack trace: $stackTrace');
      return false;
    } catch (error, stackTrace) {
      debugPrint('[DiagnosticsUploader] generic exception: $error');
      debugPrint('[DiagnosticsUploader] stack trace: $stackTrace');
      return false;
    }
  }
}
