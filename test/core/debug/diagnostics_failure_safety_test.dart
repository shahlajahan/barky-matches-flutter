import 'package:barky_matches_fixed/core/debug/diagnostics_queue.dart';
import 'package:barky_matches_fixed/core/debug/diagnostics_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnostics queue is safe before Hive has a storage path', () async {
    expect(await DiagnosticsQueue().initialize(), isFalse);
    expect(await DiagnosticsQueue().pendingReports(), isEmpty);
    await expectLater(DiagnosticsQueue().clear(), completes);
  });

  test('critical error reporting never propagates storage failures', () async {
    await expectLater(
      DiagnosticsReporter().captureCriticalError(reason: 'startup-test'),
      completes,
    );
  });
}
