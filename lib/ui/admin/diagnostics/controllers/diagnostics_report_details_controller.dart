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
  // ignore: prefer_final_fields
  bool _actionInProgress = false;
  Object? _error;

  DiagnosticsReportDetail? get detail => _detail;
  bool get loading => _loading;
  bool get actionInProgress => _actionInProgress;
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

  Future<void> markResolved() async {
    await _runAction(() => repository.markResolved(reportId));
  }

  Future<void> reopen() async {
    await _runAction(() => repository.reopen(reportId));
  }

  Future<void> ignore() async {
    await _runAction(() => repository.ignore(reportId));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) {
      return;
    }

    _actionInProgress = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      _detail = await repository.getReportDetail(reportId);
    } catch (error) {
      _error = error;
    } finally {
      _actionInProgress = false;
      notifyListeners();
    }
  }
}
