import 'dart:collection';

import 'log_category.dart';
import 'log_level.dart';

/// Immutable diagnostics record captured by the in-memory logging system.
///
/// Each entry stores a timestamp, typed category, human-readable message, and
/// optional structured metadata that can later be shipped to a remote backend.
class LogEntry {
  /// Creates a diagnostics entry.
  const LogEntry({
    required this.timestamp,
    required this.sessionId,
    required this.category,
    this.level = LogLevel.info,
    required this.message,
    this.data,
  });

  /// Time at which the log entry was created.
  final DateTime timestamp;

  /// Diagnostics session identifier shared across the current app run.
  final String sessionId;

  /// Functional area associated with the entry.
  final LogCategory category;

  /// Severity associated with the entry.
  final LogLevel level;

  /// Human-readable summary of the event.
  final String message;

  /// Optional structured metadata attached to the entry.
  final Map<String, dynamic>? data;

  /// Returns a stable serialized representation for future remote transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'category': category.name,
      'level': level.name,
      'message': message,
      if (data != null) 'data': Map<String, dynamic>.from(data!),
    };
  }

  /// Returns a copy of this entry with defensive wrapping for map data.
  LogEntry normalized() {
    if (data == null) {
      return this;
    }

    return LogEntry(
      timestamp: timestamp,
      sessionId: sessionId,
      category: category,
      level: level,
      message: message,
      data: UnmodifiableMapView<String, dynamic>(
        Map<String, dynamic>.from(data!),
      ),
    );
  }
}
