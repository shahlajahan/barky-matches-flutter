import 'package:flutter/foundation.dart';

import '../repositories/diagnostics_reports_repository.dart';

class DiagnosticsReportDetailsController extends ChangeNotifier {
  DiagnosticsReportDetailsController({
    required this.repository,
    required this.reportId,
  });

  final DiagnosticsReportsRepository repository;
  final String reportId;

  DiagnosticsReportDetail? _detail;
  // ignore: prefer_final_fields
  bool _loading = false;
  Object? _error;

  DiagnosticsReportDetail? get detail => _detail;
  bool get loading => _loading;
  Object? get error => _error;
  bool get hasError => _error != null;

  Future<void> loadReportDetail() async {
    _loading = true;
    _error = null;
    _detail = null;
    notifyListeners();

    try {
      _detail = await repository.getReportDetail(reportId);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
