import 'package:hive/hive.dart';

import 'diagnostics_report.dart';

class DiagnosticsQueue {
  factory DiagnosticsQueue() => _instance;

  DiagnosticsQueue._();

  static final DiagnosticsQueue _instance = DiagnosticsQueue._();

  static const String _boxName = 'diagnostics_queue_v1';
  static const String _reportsKey = 'pending_reports';
  static const int _maxQueueSize = 30;

  Box? _box;

  Future<void> initialize() async {
    if (_box?.isOpen == true) {
      return;
    }

    _box = await Hive.openBox(_boxName);
    await _ensureStorage();
  }

  Future<void> enqueue(DiagnosticsReport report) async {
    await initialize();

    final List<Map<String, dynamic>> reports = await _readReports();
    reports.add(report.toStorageMap());

    while (reports.length > _maxQueueSize) {
      reports.removeAt(0);
    }

    await _box!.put(_reportsKey, reports);
  }

  Future<List<DiagnosticsReport>> pendingReports() async {
    await initialize();

    final List<Map<String, dynamic>> reports = await _readReports();
    return reports
        .map(DiagnosticsReport.fromStorageMap)
        .toList(growable: false);
  }

  Future<void> remove(String reportId) async {
    await initialize();

    final List<Map<String, dynamic>> reports = await _readReports();
    reports.removeWhere(
      (Map<String, dynamic> report) => report['clientReportId'] == reportId,
    );

    await _box!.put(_reportsKey, reports);
  }

  Future<void> clear() async {
    await initialize();
    await _box!.put(_reportsKey, <Map<String, dynamic>>[]);
  }

  Future<void> _ensureStorage() async {
    if (_box!.containsKey(_reportsKey)) {
      return;
    }

    await _box!.put(_reportsKey, <Map<String, dynamic>>[]);
  }

  Future<List<Map<String, dynamic>>> _readReports() async {
    final dynamic stored = _box!.get(_reportsKey);
    if (stored is! List) {
      return <Map<String, dynamic>>[];
    }

    return stored
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: true);
  }
}
