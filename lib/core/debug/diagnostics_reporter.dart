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
  Future<void> captureCriticalError({
    required String reason,
  }) async {
    final DiagnosticsContext context = await _contextProvider.current();
    final DiagnosticsReport report = DiagnosticsReport(
      sessionId: SessionManager.sessionId,
      createdAt: DateTime.now(),
      reason: reason,
      app: context.app,
      device: context.device,
      user: context.user,
      screen: context.screen,
      logs: AppLog.buffer.snapshot(),
    );

    try {
      await DiagnosticsQueue().enqueue(report);
    } catch (_) {
      // Queue persistence is best-effort until uploader lifecycle is added.
    }
  }
}
