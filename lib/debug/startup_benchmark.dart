import 'package:flutter/foundation.dart';

class StartupBenchmark {
  StartupBenchmark._();

  static final Stopwatch _clock = Stopwatch();
  static final List<_StartupMark> _marks = <_StartupMark>[];
  static final Set<String> _oneTimeMarks = <String>{};
  static bool _started = false;
  static bool get _enabled => !kReleaseMode;

  static void start([String label = 'start']) {
    if (!_enabled) return;

    _clock
      ..reset()
      ..start();
    _marks
      ..clear()
      ..add(_StartupMark(label, Duration.zero, Duration.zero));
    _oneTimeMarks.clear();
    _started = true;
  }

  static void mark(String label) {
    if (!_enabled || !_started) return;

    final elapsed = _clock.elapsed;
    final delta = elapsed - _marks.last.elapsed;
    _marks.add(_StartupMark(label, elapsed, delta));
  }

  static void markOnce(String label) {
    if (!_enabled || !_started) return;
    if (!_oneTimeMarks.add(label)) return;
    mark(label);
  }

  static void finish([String label = 'finish']) {
    if (!_enabled || !_started) return;

    mark(label);
    _clock.stop();
    _printTable();
    _started = false;
  }

  static void _printTable() {
    final rows = _marks;
    if (rows.isEmpty) return;

    const milestoneHeader = 'Milestone';
    const totalHeader = 'Total';
    const deltaHeader = 'Delta';

    final milestoneWidth = <int>[
      milestoneHeader.length,
      ...rows.map((row) => row.label.length),
    ].reduce((a, b) => a > b ? a : b);

    final totalWidth = <int>[
      totalHeader.length,
      ...rows.map((row) => _format(row.elapsed).length),
    ].reduce((a, b) => a > b ? a : b);

    final deltaWidth = <int>[
      deltaHeader.length,
      ...rows.map((row) => _format(row.delta).length),
    ].reduce((a, b) => a > b ? a : b);

    final border =
        '+-${'-' * milestoneWidth}-+-${'-' * totalWidth}-+-${'-' * deltaWidth}-+';

    debugPrint('STARTUP BENCHMARK');
    debugPrint(border);
    debugPrint(
      '| ${milestoneHeader.padRight(milestoneWidth)} '
      '| ${totalHeader.padLeft(totalWidth)} '
      '| ${deltaHeader.padLeft(deltaWidth)} |',
    );
    debugPrint(border);

    for (final row in rows) {
      debugPrint(
        '| ${row.label.padRight(milestoneWidth)} '
        '| ${_format(row.elapsed).padLeft(totalWidth)} '
        '| ${_format(row.delta).padLeft(deltaWidth)} |',
      );
    }

    debugPrint(border);
  }

  static String _format(Duration duration) {
    return '${duration.inMilliseconds} ms';
  }
}

class _StartupMark {
  const _StartupMark(this.label, this.elapsed, this.delta);

  final String label;
  final Duration elapsed;
  final Duration delta;
}
