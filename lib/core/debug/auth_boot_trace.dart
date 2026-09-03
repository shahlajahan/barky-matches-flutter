import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Durable, privacy-safe trace of the cold-start authentication sequence.
///
/// Why this exists: the decisive interval — Firebase initialising, restoring
/// (or failing to restore) a persisted session, and the first auth event — is
/// over before `flutter logs`/`flutter run` can attach, so console logging can
/// never capture it on a real cold launch. This writes the same facts to a
/// Hive box that survives process death, so the previous launch can be read
/// back after the app is already sitting on Welcome.
///
/// Privacy contract, enforced here rather than left to call sites:
///  * UIDs are stored only as a truncated SHA-256 digest ([redactUid]).
///  * Emails, tokens, credentials, API keys and Firebase secrets are never
///    accepted — [record] copies only bool/num/short-String values.
///  * Provider IDs (`google.com`, `apple.com`, `password`) and boolean flags
///    are retained; they are not personal data and are what the diagnosis
///    turns on.
///
/// Bounded and rotating: at most [maxEventsPerBoot] events per launch and
/// [maxBoots] launches are retained, so the box cannot grow without limit.
///
/// This is diagnostics only. It never influences routing, never decides
/// authentication, and every method is failure-tolerant — a broken box
/// degrades to in-memory recording and must never break startup.
class AuthBootTrace {
  AuthBootTrace._();

  static const String boxName = 'auth_boot_trace_v1';
  static const String _bootsKey = 'boots';
  static const int maxEventsPerBoot = 200;
  static const int maxBoots = 3;

  /// Values longer than this are truncated rather than stored, so an
  /// unexpected payload cannot smuggle a token or an email into the trace.
  static const int _maxValueLength = 120;

  static Box<dynamic>? _box;
  static bool _initialized = false;
  static int _seq = 0;
  static String _bootId = '';
  static final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  static List<dynamic> _previousBoots = <dynamic>[];

  /// Only debug/profile builds trace. `kReleaseMode` short-circuits every
  /// entry point so production writes nothing.
  static bool get isEnabled => !kReleaseMode;

  /// The previous launches, as loaded at [initialize] time. Exposed so the
  /// retrieval path can report the cold start that already happened.
  static List<dynamic> get previousBoots =>
      List<dynamic>.unmodifiable(_previousBoots);

  /// Opens the box, snapshots prior launches, and starts a new boot record.
  ///
  /// Must be called after `Hive.initFlutter()` and before Firebase
  /// initialisation, so the very first auth facts are inside the trace.
  static Future<void> initialize() async {
    if (!isEnabled || _initialized) return;
    _initialized = true;

    _bootId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

    try {
      _box = await Hive.openBox<dynamic>(boxName);
      final dynamic stored = _box?.get(_bootsKey);
      if (stored is List) {
        _previousBoots = List<dynamic>.from(stored);
      }
    } catch (e) {
      // Never block startup on diagnostics.
      debugPrint('⚠️ AuthBootTrace: box unavailable, in-memory only ($e)');
      _box = null;
    }

    record(
      'boot_start',
      data: <String, Object?>{
        'previousBoots': _previousBoots.length,
        'platform': defaultTargetPlatform.name,
        'buildMode': kDebugMode
            ? 'debug'
            : kProfileMode
            ? 'profile'
            : 'release',
      },
    );
  }

  /// Appends one event. Safe to call before [initialize] (buffered in memory)
  /// and safe to call from any startup path.
  static void record(String event, {Map<String, Object?>? data}) {
    if (!isEnabled) return;

    final entry = <String, dynamic>{
      'seq': _seq++,
      'tsMs': DateTime.now().millisecondsSinceEpoch,
      'event': event,
      if (data != null && data.isNotEmpty) 'data': _sanitize(data),
    };

    _events.add(entry);
    if (_events.length > maxEventsPerBoot) {
      _events.removeAt(0);
    }

    unawaited(_flush());
  }

  /// Records what `FirebaseAuth.instance.currentUser` reports at a named
  /// point. This is the single most decisive fact in the investigation: if a
  /// cold launch shows `hasUser: false` here while the previous launch ended
  /// with `hasUser: true` and no sign-out, then Firebase itself did not
  /// restore the persisted session and the cause is outside application code.
  static void recordCurrentUserSnapshot(String label) {
    if (!isEnabled) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      record(
        'current_user_snapshot',
        data: <String, Object?>{'at': label, ..._userFacts(user)},
      );
    } catch (e) {
      record(
        'current_user_snapshot_failed',
        data: <String, Object?>{'at': label, 'error': e.runtimeType.toString()},
      );
    }
  }

  /// Extracts the auth facts we care about from any `User`-shaped object.
  ///
  /// Every field is read under its own guard: diagnostics must never be able
  /// to throw into the auth listener or into startup, whatever implementation
  /// of `User` is in play.
  static Map<String, Object?> _userFacts(Object? user) {
    if (user == null) return <String, Object?>{'hasUser': false};

    String? uid;
    bool? isAnonymous;
    bool? emailVerified;
    List<String>? providers;

    try {
      uid = redactUid((user as dynamic).uid as String?);
    } catch (_) {}
    try {
      isAnonymous = (user as dynamic).isAnonymous as bool?;
    } catch (_) {}
    try {
      emailVerified = (user as dynamic).emailVerified as bool?;
    } catch (_) {}
    try {
      providers = ((user as dynamic).providerData as List)
          .map((p) => (p as dynamic).providerId as String)
          .toList(growable: false);
    } catch (_) {}

    return <String, Object?>{
      'hasUser': true,
      'uid': uid,
      'isAnonymous': isAnonymous,
      'emailVerified': emailVerified,
      'providers': providers,
    };
  }

  /// Records one auth-stream emission.
  static void recordAuthEvent(
    Object? user, {
    required bool sdkCurrentUserPresent,
  }) {
    if (!isEnabled) return;
    record(
      'auth_event',
      data: <String, Object?>{
        ..._userFacts(user),
        'sdkCurrentUserPresent': sdkCurrentUserPresent,
      },
    );
  }

  /// Truncated SHA-256 of a UID: stable enough to correlate two launches,
  /// never the UID itself.
  static String? redactUid(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    final digest = sha256.convert(utf8.encode(uid)).toString();
    return 'uid#${digest.substring(0, 12)}';
  }

  /// Anything that looks like an opaque identifier — a Firebase UID is 28
  /// alphanumeric characters — is scrubbed from free-text values.
  ///
  /// Call sites are expected to pass [redactUid] output, but a reason string
  /// or message can be composed anywhere in the codebase, so the guarantee is
  /// enforced here rather than trusted upstream. `uid#<12 hex>` digests are
  /// shorter than the threshold and survive.
  static final RegExp _identifierLike = RegExp(r'[A-Za-z0-9_-]{20,}');

  static String scrubIdentifiers(String value) =>
      value.replaceAll(_identifierLike, '<redacted>');

  /// Copies only primitives, and truncates strings. Anything else is recorded
  /// as its type name, so an unexpected object cannot leak its contents.
  static Map<String, dynamic> _sanitize(Map<String, Object?> data) {
    final safe = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null || value is bool || value is num) {
        safe[key] = value;
      } else if (value is String) {
        final scrubbed = scrubIdentifiers(value);
        safe[key] = scrubbed.length <= _maxValueLength
            ? scrubbed
            : '${scrubbed.substring(0, _maxValueLength)}…';
      } else if (value is List) {
        safe[key] = value
            .whereType<String>()
            .take(10)
            .map(scrubIdentifiers)
            .map(
              (e) => e.length <= _maxValueLength
                  ? e
                  : '${e.substring(0, _maxValueLength)}…',
            )
            .toList();
      } else {
        safe[key] = '<${value.runtimeType}>';
      }
    });
    return safe;
  }

  static Future<void> _flush() async {
    final box = _box;
    if (box == null || !box.isOpen) return;

    try {
      final boots = List<dynamic>.from(_previousBoots)
        ..add(<String, dynamic>{
          'bootId': _bootId,
          'events': List<Map<String, dynamic>>.from(_events),
        });

      // Keep only the most recent launches.
      final trimmed = boots.length > maxBoots
          ? boots.sublist(boots.length - maxBoots)
          : boots;

      await box.put(_bootsKey, trimmed);
    } catch (e) {
      debugPrint('⚠️ AuthBootTrace: flush failed ($e)');
    }
  }

  /// Human-readable rendering of the persisted launches, newest last.
  static String export({bool includeCurrentBoot = true}) {
    final buffer = StringBuffer()
      ..writeln('===== AUTH BOOT TRACE =====')
      ..writeln('previous launches retained: ${_previousBoots.length}');

    for (var i = 0; i < _previousBoots.length; i++) {
      final boot = _previousBoots[i];
      if (boot is! Map) continue;
      buffer.writeln('--- previous launch ${i + 1} (${boot['bootId']}) ---');
      _writeEvents(buffer, boot['events']);
    }

    if (includeCurrentBoot) {
      buffer.writeln('--- current launch ($_bootId) ---');
      _writeEvents(buffer, _events);
    }

    buffer.writeln('===== END AUTH BOOT TRACE =====');
    return buffer.toString();
  }

  static void _writeEvents(StringBuffer buffer, dynamic events) {
    if (events is! List) return;
    int? firstTs;
    for (final raw in events) {
      if (raw is! Map) continue;
      final ts = raw['tsMs'];
      firstTs ??= ts is int ? ts : null;
      final offset = (ts is int && firstTs != null) ? ts - firstTs : 0;
      final data = raw['data'];
      buffer.writeln(
        '  [${raw['seq']}] +${offset}ms ${raw['event']}'
        '${data == null ? '' : ' $data'}',
      );
    }
  }

  /// Prints the persisted trace. Repeated a few times after launch so the
  /// record is still emitted once `flutter logs` attaches — the whole point
  /// being that the interesting events are already over by then.
  static void dumpToLog({String reason = 'manual'}) {
    if (!isEnabled) return;
    debugPrint('🧾 AuthBootTrace dump ($reason)\n${export()}');
  }

  static Timer? _scheduledDump;

  /// Schedules delayed dumps so the operator can attach `flutter logs` after
  /// the app has already settled on its startup destination.
  static void scheduleDumps({
    List<Duration> delays = const <Duration>[
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
  }) {
    if (!isEnabled) return;

    for (final delay in delays) {
      Timer(delay, () => dumpToLog(reason: 'scheduled@${delay.inSeconds}s'));
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
    _seq = 0;
    _bootId = '';
    _events.clear();
    _previousBoots = <dynamic>[];
    _box = null;
    _scheduledDump?.cancel();
    _scheduledDump = null;
  }

  @visibleForTesting
  static List<Map<String, dynamic>> get currentEvents =>
      List<Map<String, dynamic>>.unmodifiable(_events);
}
