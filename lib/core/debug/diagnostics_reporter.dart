import 'dart:collection';

import 'app_log.dart';
import 'diagnostics_report.dart';
import 'session_manager.dart';

/// Memory-only entry point for capturing diagnostics reports.
///
/// This class intentionally performs no network requests and does not persist
/// reports. It only stages unique reports in memory for future sending.
class DiagnosticsReporter {
  factory DiagnosticsReporter() => _instance;

  DiagnosticsReporter._();

  static final DiagnosticsReporter _instance = DiagnosticsReporter._();

  final ListQueue<DiagnosticsReport> _pendingReports =
      ListQueue<DiagnosticsReport>();
  final Set<String> _capturedFingerprints = <String>{};

  /// Returns `true` when at least one unsent report is staged in memory.
  bool get hasPendingReport => _pendingReports.isNotEmpty;

  /// Captures the current diagnostics buffer into an immutable report.
  ///
  /// Duplicate captures within the current app session are ignored.
  Future<void> captureCriticalError({
    required String reason,
  }) async {
    final DiagnosticsReport report = DiagnosticsReport(
      sessionId: SessionManager.sessionId,
      createdAt: DateTime.now(),
      reason: reason,
      logs: AppLog.buffer.snapshot(),
    );

    final String fingerprint = _fingerprint(report);
    if (_capturedFingerprints.contains(fingerprint)) {
      return;
    }

    _capturedFingerprints.add(fingerprint);
    _pendingReports.addLast(report);
  }

  String _fingerprint(DiagnosticsReport report) {
    return report.toMap().toString();
  }
}
