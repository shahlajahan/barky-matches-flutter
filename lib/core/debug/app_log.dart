import 'package:flutter/foundation.dart';

import 'diagnostics_buffer.dart';
import 'log_category.dart';
import 'log_entry.dart';
import 'log_level.dart';
import 'session_manager.dart';

/// Central diagnostics entry point for production-safe application logging.
///
/// `AppLog` keeps a bounded in-memory history for future remote diagnostics
/// while printing to the console only in debug builds.
class AppLog {
  AppLog._();

  static final DiagnosticsBuffer _buffer = DiagnosticsBuffer();

  /// Exposes the shared in-memory diagnostics buffer.
  static DiagnosticsBuffer get buffer => _buffer;

  /// Records an authentication-related event.
  static void auth(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.auth, message, data: data);
  }

  /// Records a navigation-related event.
  static void nav(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.nav, message, data: data);
  }

  /// Records a Firestore-related event.
  static void firestore(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.firestore, message, data: data);
  }

  /// Records a storage-related event.
  static void storage(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.storage, message, data: data);
  }

  /// Records a network-related event.
  static void network(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.network, message, data: data);
  }

  /// Records a payment-related event.
  static void payment(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.payment, message, data: data);
  }

  /// Records a map-related event.
  static void map(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.map, message, data: data);
  }

  /// Records a location-related event.
  static void location(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.location, message, data: data);
  }

  /// Records an image-related event.
  static void image(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.image, message, data: data);
  }

  /// Records a notification-related event.
  static void notification(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.notification, message, data: data);
  }

  /// Records a UI-related event.
  static void ui(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.ui, message, data: data);
  }

  /// Records a performance-related event.
  static void performance(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.performance, message, data: data);
  }

  /// Records an error-related event.
  static void error(String message, {Map<String, dynamic>? data}) {
    _log(LogCategory.error, message, data: data);
  }

  static void _log(
    LogCategory category,
    String message, {
    Map<String, dynamic>? data,
    LogLevel level = LogLevel.info,
  }) {
    final LogEntry entry = LogEntry(
      timestamp: DateTime.now(),
      sessionId: SessionManager.sessionId,
      category: category,
      level: level,
      message: message,
      data: data,
    );

    _buffer.add(entry);

    if (kDebugMode) {
      debugPrint(_format(entry));
    }
  }

  static String _format(LogEntry entry) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('======================================')
      ..writeln(entry.category.name.toUpperCase())
      ..writeln()
      ..writeln('Level:')
      ..writeln(entry.level.name.toUpperCase())
      ..writeln()
      ..writeln('Session:')
      ..writeln(entry.sessionId)
      ..writeln()
      ..writeln('Time:')
      ..writeln(_formatTime(entry.timestamp))
      ..writeln()
      ..writeln('Message:')
      ..writeln(entry.message);

    if (entry.data != null && entry.data!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Data:');

      entry.data!.forEach((String key, dynamic value) {
        buffer.writeln('$key: $value');
      });
    }

    buffer.write('======================================');
    return buffer.toString();
  }

  static String _formatTime(DateTime timestamp) {
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    final String second = timestamp.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }
}
