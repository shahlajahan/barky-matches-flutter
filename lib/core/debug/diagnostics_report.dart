import 'dart:collection';

import 'log_entry.dart';

/// Immutable in-memory diagnostics bundle captured for later delivery.
class DiagnosticsReport {
  factory DiagnosticsReport({
    required String sessionId,
    required DateTime createdAt,
    required String reason,
    required Iterable<LogEntry> logs,
  }) {
    final List<LogEntry> normalizedLogs = List<LogEntry>.unmodifiable(
      logs.map((LogEntry entry) => entry.normalized()),
    );

    return DiagnosticsReport._(
      sessionId: sessionId,
      createdAt: createdAt,
      reason: reason,
      logCount: normalizedLogs.length,
      logs: UnmodifiableListView<LogEntry>(normalizedLogs),
    );
  }

  const DiagnosticsReport._({
    required this.sessionId,
    required this.createdAt,
    required this.reason,
    required this.logCount,
    required this.logs,
  });

  final String sessionId;
  final DateTime createdAt;
  final String reason;
  final int logCount;
  final List<LogEntry> logs;

  /// Returns a stable serialized representation for future transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'reason': reason,
      'logCount': logCount,
      'logs': logs.map((LogEntry entry) => entry.toMap()).toList(),
    };
  }
}
