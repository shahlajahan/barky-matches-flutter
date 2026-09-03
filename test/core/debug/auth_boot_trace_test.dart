import 'package:barky_matches_fixed/core/debug/auth_boot_trace.dart';
import 'package:flutter_test/flutter_test.dart';

/// These cover the trace's *privacy and safety* contract only.
///
/// They deliberately do NOT claim anything about iOS Keychain persistence or
/// about whether a session survives a cold launch — no unit test can prove
/// that. The trace exists precisely because only a physical device can.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AuthBootTrace.resetForTest);
  tearDown(AuthBootTrace.resetForTest);

  group('uid redaction', () {
    test('never returns the raw uid', () {
      const uid = 'AbCdEf1234567890XyZ';
      final redacted = AuthBootTrace.redactUid(uid);

      expect(redacted, isNotNull);
      expect(redacted, isNot(contains(uid)));
      expect(redacted, startsWith('uid#'));
    });

    test('is stable for the same uid and differs across uids', () {
      expect(
        AuthBootTrace.redactUid('user-a'),
        AuthBootTrace.redactUid('user-a'),
      );
      expect(
        AuthBootTrace.redactUid('user-a'),
        isNot(AuthBootTrace.redactUid('user-b')),
      );
    });

    test('null and empty yield null', () {
      expect(AuthBootTrace.redactUid(null), isNull);
      expect(AuthBootTrace.redactUid(''), isNull);
    });
  });

  group('event recording', () {
    test('records sequence numbers and timestamps', () {
      AuthBootTrace.record('first');
      AuthBootTrace.record('second');

      final events = AuthBootTrace.currentEvents;
      expect(events.length, 2);
      expect(events[0]['seq'], 0);
      expect(events[1]['seq'], 1);
      expect(events[0]['tsMs'], isA<int>());
      expect(events[1]['event'], 'second');
    });

    test('is bounded per boot', () {
      for (var i = 0; i < AuthBootTrace.maxEventsPerBoot + 50; i++) {
        AuthBootTrace.record('e$i');
      }

      expect(
        AuthBootTrace.currentEvents.length,
        AuthBootTrace.maxEventsPerBoot,
        reason: 'the trace must not grow without limit',
      );
    });

    test('long strings are truncated rather than stored whole', () {
      AuthBootTrace.record('x', data: <String, Object?>{'v': 'a' * 500});

      final stored = AuthBootTrace.currentEvents.single['data']['v'] as String;
      expect(stored.length, lessThan(500));
      expect(stored, endsWith('…'));
    });

    test('non-primitive values are reduced to a type name', () {
      AuthBootTrace.record(
        'x',
        data: <String, Object?>{
          'obj': Object(),
          'map': <String, int>{'a': 1},
        },
      );

      final data = AuthBootTrace.currentEvents.single['data'];
      expect(data['obj'], '<Object>');
      expect((data['map'] as String), startsWith('<'));
    });
  });

  group('auth event extraction never throws', () {
    test('a User-shaped object missing every member is tolerated', () {
      // Mirrors a minimal fake whose unimplemented members throw.
      AuthBootTrace.recordAuthEvent(
        _HostileUser(),
        sdkCurrentUserPresent: true,
      );

      final data = AuthBootTrace.currentEvents.single['data'];
      expect(data['hasUser'], isTrue);
      expect(data['sdkCurrentUserPresent'], isTrue);
      // Fields that threw are simply absent/null, not fatal.
      expect(data['uid'], isNull);
    });

    test('null user records hasUser false', () {
      AuthBootTrace.recordAuthEvent(null, sdkCurrentUserPresent: false);

      final data = AuthBootTrace.currentEvents.single['data'];
      expect(data['hasUser'], isFalse);
      expect(data['sdkCurrentUserPresent'], isFalse);
    });
  });

  group('export', () {
    test('renders recorded events and is safe with no prior boots', () {
      AuthBootTrace.record('boot_start');
      AuthBootTrace.record(
        'auth_event',
        data: <String, Object?>{'hasUser': false},
      );

      final text = AuthBootTrace.export();
      expect(text, contains('AUTH BOOT TRACE'));
      expect(text, contains('boot_start'));
      expect(text, contains('auth_event'));
      expect(text, contains('previous launches retained: 0'));
    });
  });
}

/// Every member access throws, standing in for a partially-implemented `User`.
class _HostileUser {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
