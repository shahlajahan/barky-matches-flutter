import 'package:flutter_test/flutter_test.dart';

// Imports the stub implementation directly (used on non-web platforms, and
// structurally identical in spirit to what an absent/mismatched JS global
// degrades to on Web — see web_startup_status_web.dart's own defensive
// existence/callable checks for the Web-specific half of this guarantee).
import 'package:barky_matches_fixed/core/debug/web_startup_status_stub.dart';

void main() {
  group('hideWebStartupStatus (non-web / absent-global safety)', () {
    test('is a safe no-op and never throws', () {
      expect(hideWebStartupStatus, returnsNormally);
    });

    test(
      'is safe to call repeatedly (idempotent under rapid taps/rebuilds)',
      () {
        expect(() {
          hideWebStartupStatus();
          hideWebStartupStatus();
          hideWebStartupStatus();
        }, returnsNormally);
      },
    );
  });
}
