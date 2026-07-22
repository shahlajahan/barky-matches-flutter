import 'app_log.dart';
import 'diagnostics_context_provider.dart';
import 'diagnostics_queue.dart';
import 'diagnostics_report.dart';
import 'session_manager.dart';

/// Captures diagnostics reports and stages them for later delivery.
///
/// This class intentionally performs no network requests. Reports are persisted
/// only through the diagnostics queue.
class DiagnosticsReporter {
  factory DiagnosticsReporter() => _instance;

  DiagnosticsReporter._();

  static final DiagnosticsReporter _instance = DiagnosticsReporter._();
  final DiagnosticsContextProvider _contextProvider =
      DiagnosticsContextProvider();

  /// Captures the current diagnostics buffer into an immutable report.
  Future<void> captureCriticalError({required String reason}) async {
    await _capture(
      reason: reason,
      severity: DiagnosticsReport.criticalSeverity,
    );
  }

  /// Captures a diagnostics event using the existing report pipeline.
  Future<void> captureDiagnosticEvent({
    required String reason,
    String severity = 'warning',
  }) async {
    await _capture(reason: reason, severity: severity);
  }

  Future<void> _capture({
    required String reason,
    required String severity,
  }) async {
    try {
      final DiagnosticsContext context = await _contextProvider.current();
      final DiagnosticsReport report = DiagnosticsReport(
        sessionId: SessionManager.sessionId,
        createdAt: DateTime.now(),
        reason: reason,
        severity: severity,
        app: context.app,
        device: context.device,
        user: context.user,
        screen: context.screen,
        logs: AppLog.buffer.snapshot(),
      );

      await DiagnosticsQueue().enqueue(report);
    } catch (_) {
      // Diagnostics are best-effort and must never become a second failure.
    }
  }
}
