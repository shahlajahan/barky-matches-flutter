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
  bool _persistenceEnabled = false;

  /// Enables Hive persistence after application startup has configured Hive.
  void enablePersistence() {
    _persistenceEnabled = true;
  }

  Future<bool> initialize() async {
    if (_box?.isOpen == true) {
      return true;
    }
    if (!_persistenceEnabled) {
      return false;
    }

    try {
      _box = await Hive.openBox(_boxName);
      await _ensureStorage();
      return true;
    } catch (_) {
      _box = null;
      return false;
    }
  }

  Future<void> enqueue(DiagnosticsReport report) async {
    if (!await initialize()) return;

    final List<Map<String, dynamic>> reports = await _readReports();
    reports.add(report.toStorageMap());

    while (reports.length > _maxQueueSize) {
      reports.removeAt(0);
    }

    await _box!.put(_reportsKey, reports);
  }

  Future<List<DiagnosticsReport>> pendingReports() async {
    if (!await initialize()) return <DiagnosticsReport>[];

    final List<Map<String, dynamic>> reports = await _readReports();
    return reports
        .map(DiagnosticsReport.fromStorageMap)
        .toList(growable: false);
  }

  Future<void> remove(String reportId) async {
    if (!await initialize()) return;

    final List<Map<String, dynamic>> reports = await _readReports();
    reports.removeWhere(
      (Map<String, dynamic> report) => report['clientReportId'] == reportId,
    );

    await _box!.put(_reportsKey, reports);
  }

  Future<void> clear() async {
    if (!await initialize()) return;
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
