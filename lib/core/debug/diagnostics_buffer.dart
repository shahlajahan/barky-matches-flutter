import 'dart:collection';

import 'log_entry.dart';

/// Fixed-capacity in-memory ring buffer for diagnostics entries.
///
/// This buffer intentionally keeps logs only in process memory. When capacity
/// is exceeded, the oldest entries are discarded first.
class DiagnosticsBuffer {
  /// Creates a diagnostics buffer with an optional custom capacity.
  DiagnosticsBuffer({this.capacity = 300}) : assert(capacity > 0);

  /// Maximum number of entries retained in memory.
  final int capacity;

  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();

  /// Adds an entry to the buffer, evicting the oldest item if necessary.
  void add(LogEntry entry) {
    if (_entries.length == capacity) {
      _entries.removeFirst();
    }

    _entries.addLast(entry.normalized());
  }

  /// Returns the current buffered entries in oldest-to-newest order.
  List<LogEntry> snapshot() {
    return List<LogEntry>.unmodifiable(_entries);
  }

  /// Removes all buffered entries.
  void clear() {
    _entries.clear();
  }

  /// Returns the number of entries currently held in memory.
  int get length => _entries.length;

  /// Returns `true` when no entries are currently buffered.
  bool get isEmpty => _entries.isEmpty;
}
