import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/firestore_recovery.dart';

class AuthTrap {
  AuthTrap._();

  static bool _started = false;
  static bool _tokenDiagnosticsScheduled = false;
  static bool _tokenDiagnosticsRunning = false;
  static int _tokenDiagnosticsRetryCount = 0;
  static int _tokenDiagnosticsRunId = 0;
  static int _tokenProbeInternalErrorCount = 0;
  static DateTime? _tokenProbeCooldownUntil;
  static Timer? _tokenDiagnosticsTimer;
  static String? lastMarker;
  static bool _hadAuthenticatedUser = false;
  static bool enableVerboseDiagnostics = kDebugMode;
  static bool enableDiagnosticsAuthReset = false;
  static bool authProbeMinimalMode = true;

  /// Call this ONCE after Firebase.initializeApp()
  static void start() {
    if (_started) return;
    _started = true;

    if (enableVerboseDiagnostics) {
      debugPrint('🧨 AuthTrap.start()');
    }

    if (authProbeMinimalMode) {
      debugPrint('🌐 AUTH MINIMAL MODE ACTIVE');
      debugPrint('🌐 TOKEN PROBES DISABLED');
    }

    FirebaseAuth.instance.userChanges().listen(
      (user) {
        if (!enableVerboseDiagnostics) {
          return;
        }

        final now = DateTime.now().toIso8601String();

        debugPrint(
          '🧨 [AuthTrap] userChanges @ $now -> ${user?.uid ?? "NULL"} | marker=$lastMarker',
        );

        if (user == null) {
          if (_hadAuthenticatedUser) {
            debugPrint(
              '⚠️ AuthTrap user became NULL after auth session → marker=$lastMarker',
            );
            debugPrintStack(label: '🧨 AuthTrap user NULL stack');
          } else {
            debugPrint('ℹ️ AuthTrap initial NULL auth state → guest mode');
          }
          return;
        }

        _hadAuthenticatedUser = true;
      },
      onError: (e, s) {
        if (enableVerboseDiagnostics) {
          debugPrint('🧨 AuthTrap userChanges ERROR: $e');
          debugPrint('$s');
        }
      },
    );

    debugPrint('🌐 AUTH TRAP ATTACHED');
  }

  static void mark(String tag) {
    lastMarker = tag;
    if (enableVerboseDiagnostics) {
      debugPrint(
        '🧨 AuthTrap MARK -> $tag | uid=${FirebaseAuth.instance.currentUser?.uid}',
      );
    }
  }

  static void scheduleTokenDiagnostics({
    Duration initialDelay = const Duration(seconds: 10),
  }) {
    if (!enableVerboseDiagnostics) return;
    if (authProbeMinimalMode) {
      debugPrint('🌐 TOKEN PROBES DISABLED → AuthTrap diagnostics skipped');
      _stopTokenDiagnostics();
      return;
    }
    if (shouldSuppressTokenProbe('AuthTrap.scheduleTokenDiagnostics')) return;
    if (_tokenDiagnosticsScheduled) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → token diagnostics already scheduled',
      );
      return;
    }
    if (_tokenDiagnosticsRunning) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → token diagnostics already running',
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('🌐 token diagnostics skipped (no currentUser)');
      return;
    }
    _tokenDiagnosticsScheduled = true;

    _tokenDiagnosticsTimer?.cancel();
    _tokenDiagnosticsTimer = Timer(initialDelay, () {
      unawaited(_runTokenDiagnostics());
    });
  }

  static Future<void> _runTokenDiagnostics() async {
    if (!enableVerboseDiagnostics) return;
    if (authProbeMinimalMode) {
      debugPrint('🌐 TOKEN PROBES DISABLED → AuthTrap run suppressed');
      _stopTokenDiagnostics();
      return;
    }
    if (shouldSuppressTokenProbe('AuthTrap.runTokenDiagnostics')) return;
    if (_tokenDiagnosticsRunning) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → token diagnostics overlap blocked',
      );
      return;
    }
    if (FirestoreRecovery.isRecoveryActive) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → token diagnostics delayed during Firestore recovery',
      );
      _scheduleTokenDiagnosticsRetry();
      return;
    }
    _tokenDiagnosticsRunning = true;
    final runId = ++_tokenDiagnosticsRunId;
    debugPrint('🌐 TOKEN DIAGNOSTIC START → run=$runId');

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      debugPrint(
        '🧪 Auth token diagnostics start → uid=${user?.uid ?? "NULL"} marker=$lastMarker retry=$_tokenDiagnosticsRetryCount',
      );

      if (user == null) {
        debugPrint('🧪 Auth token diagnostics skipped (no currentUser)');
        _stopTokenDiagnostics();
        return;
      }

      try {
        debugPrint(
          '🧪 Auth snapshot → '
          'uid=${user.uid} '
          'anonymous=${user.isAnonymous} '
          'tenantId=${user.tenantId ?? "NULL"} '
          'providerCount=${user.providerData.length}',
        );
        debugPrint(
          '🧪 Auth metadata → '
          'created=${user.metadata.creationTime?.toIso8601String() ?? "NULL"} '
          'signedIn=${user.metadata.lastSignInTime?.toIso8601String() ?? "NULL"}',
        );
        for (final provider in user.providerData) {
          debugPrint(
            '🧪 providerData → '
            'providerId=${provider.providerId} '
            'uid=${provider.uid ?? "NULL"} '
            'email=${provider.email ?? "NULL"}',
          );
        }

        Future<void> probeToken({
          required String label,
          required Future<String?> Function() getter,
        }) async {
          if (shouldSuppressTokenProbe(label)) return;
          try {
            final token = await getter();
            recordTokenProbeSuccess(label);
            debugPrint(
              '🧪 $label success → uid=${user.uid} tokenLength=${token?.length ?? 0}',
            );
          } on FirebaseAuthException catch (e, st) {
            recordTokenProbeFailure(label, e);
            debugPrint(
              '🧪 $label FirebaseAuthException → plugin=${e.plugin} code=${e.code} message=${e.message}',
            );
            debugPrint('$st');
          } catch (e, st) {
            debugPrint('🧪 $label error → $e');
            debugPrint('$st');
          }
        }

        await probeToken(
          label: 'getIdToken(false)',
          getter: () => user.getIdToken(false),
        );

        bool forcedRefreshFailed = false;
        try {
          if (shouldSuppressTokenProbe('getIdToken(true)')) {
            return;
          }
          final token = await user.getIdToken(true);
          recordTokenProbeSuccess('getIdToken(true)');
          debugPrint(
            '🧪 getIdToken(true) success → uid=${user.uid} tokenLength=${token?.length ?? 0}',
          );
        } on FirebaseAuthException catch (e, st) {
          forcedRefreshFailed = true;
          recordTokenProbeFailure('getIdToken(true)', e);
          debugPrint(
            '⚠️ getIdToken(true) failed → plugin=${e.plugin} code=${e.code} message=${e.message}',
          );
          debugPrint('$st');
          debugPrint('🧪 preserving session; will retry token refresh later');
        } catch (e, st) {
          forcedRefreshFailed = true;
          debugPrint('⚠️ getIdToken(true) transient error → $e');
          debugPrint('$st');
          debugPrint('🧪 preserving session; will retry token refresh later');
        }

        try {
          if (shouldSuppressTokenProbe('getIdTokenResult(false)')) {
            return;
          }
          final result = await user.getIdTokenResult(false);
          recordTokenProbeSuccess('getIdTokenResult(false)');
          debugPrint(
            '🧪 getIdTokenResult(false) → '
            'issuedAt=${result.issuedAtTime?.toIso8601String() ?? "NULL"} '
            'authTime=${result.authTime?.toIso8601String() ?? "NULL"} '
            'expiresAt=${result.expirationTime?.toIso8601String() ?? "NULL"} '
            'signInProvider=${result.signInProvider ?? "NULL"}',
          );
        } on FirebaseAuthException catch (e, st) {
          recordTokenProbeFailure('getIdTokenResult(false)', e);
          debugPrint(
            '🧪 getIdTokenResult(false) FirebaseAuthException → '
            'plugin=${e.plugin} code=${e.code} message=${e.message}',
          );
          debugPrint('$st');
        } catch (e, st) {
          debugPrint('🧪 getIdTokenResult(false) error → $e');
          debugPrint('$st');
        }

        try {
          if (shouldSuppressTokenProbe('user.reload()')) {
            return;
          }
          await user.reload();
          recordTokenProbeSuccess('user.reload()');
          debugPrint(
            '🧪 user.reload() completed → uid=${auth.currentUser?.uid}',
          );
        } on FirebaseAuthException catch (e, st) {
          recordTokenProbeFailure('user.reload()', e);
          debugPrint(
            '🧪 user.reload() FirebaseAuthException → plugin=${e.plugin} code=${e.code} message=${e.message}',
          );
          debugPrint('$st');
        } catch (e, st) {
          debugPrint('🧪 user.reload() error → $e');
          debugPrint('$st');
        }

        if (forcedRefreshFailed) {
          _scheduleTokenDiagnosticsRetry();
        } else {
          _stopTokenDiagnostics();
        }
      } catch (e, st) {
        debugPrint('🧪 Auth token diagnostics error → $e');
        debugPrint('$st');
        _scheduleTokenDiagnosticsRetry();
      }
    } finally {
      debugPrint('🌐 TOKEN DIAGNOSTIC END → run=$runId');
      _tokenDiagnosticsRunning = false;
    }
  }

  static void _scheduleTokenDiagnosticsRetry() {
    if (!enableVerboseDiagnostics) return;
    if (authProbeMinimalMode) {
      debugPrint('🌐 TOKEN PROBES DISABLED → token retry suppressed');
      _stopTokenDiagnostics();
      return;
    }
    final cooldownRemaining = tokenProbeCooldownRemaining;
    if (cooldownRemaining > Duration.zero) {
      debugPrint(
        '🌐 TOKEN PROBE COOLDOWN ACTIVE → retry delayed ${cooldownRemaining.inSeconds}s',
      );
      _tokenDiagnosticsTimer?.cancel();
      _tokenDiagnosticsTimer = Timer(cooldownRemaining, () {
        unawaited(_runTokenDiagnostics());
      });
      return;
    }

    _tokenDiagnosticsRetryCount = (_tokenDiagnosticsRetryCount + 1).clamp(1, 6);
    final delay = Duration(seconds: 10 * _tokenDiagnosticsRetryCount);

    debugPrint(
      '🧪 getIdToken(true) retry scheduled in ${delay.inSeconds}s → preserving session',
    );

    _tokenDiagnosticsTimer?.cancel();
    _tokenDiagnosticsTimer = Timer(delay, () {
      unawaited(_runTokenDiagnostics());
    });
  }

  static void _stopTokenDiagnostics() {
    _tokenDiagnosticsRetryCount = 0;
    _tokenDiagnosticsScheduled = false;
    _tokenDiagnosticsTimer?.cancel();
    _tokenDiagnosticsTimer = null;
  }

  static Duration get tokenProbeCooldownRemaining {
    final until = _tokenProbeCooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _tokenProbeCooldownUntil = null;
      _tokenProbeInternalErrorCount = 0;
      return Duration.zero;
    }
    return remaining;
  }

  static bool shouldSuppressTokenProbe(String source) {
    final remaining = tokenProbeCooldownRemaining;
    if (remaining <= Duration.zero) return false;

    debugPrint(
      '🌐 TOKEN PROBE SUPPRESSED → $source cooldown=${remaining.inSeconds}s',
    );
    return true;
  }

  static void recordTokenProbeSuccess(String source) {
    _tokenProbeInternalErrorCount = 0;
    _tokenProbeCooldownUntil = null;
  }

  static void recordTokenProbeFailure(String source, Object error) {
    if (!_isInternalAuthError(error)) return;

    _tokenProbeInternalErrorCount++;
    debugPrint(
      '🌐 TOKEN PROBE INTERNAL ERROR → $source count=$_tokenProbeInternalErrorCount',
    );

    if (_tokenProbeInternalErrorCount < 2) return;

    _tokenProbeCooldownUntil = DateTime.now().add(const Duration(seconds: 90));
    _tokenDiagnosticsTimer?.cancel();
    _tokenDiagnosticsTimer = null;
    _tokenDiagnosticsScheduled = false;
    debugPrint('🌐 TOKEN PROBE COOLDOWN ACTIVE → 90s');
  }

  static bool _isInternalAuthError(Object error) {
    if (error is FirebaseAuthException) {
      return error.code == 'internal-error';
    }
    return error.toString().toLowerCase().contains('internal-error');
  }

  static Future<void> resetNativeAuthState({required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;

    debugPrint(
      '⚠️ FirebaseAuth native state reset disabled → preserving session ($reason)',
    );
    if (user != null) {
      debugPrint('⚠️ reset request ignored for uid=${user.uid}');
    }
  }

  static Future<void> signOut({required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('⚠️ user already null → skip signOut');
      return;
    }

    debugPrint('SIGNOUT → $reason | uid=${user.uid}');

    try {
      await FirebaseAuth.instance.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ signOut timeout → continuing local logout flow');
        },
      );
    } catch (e, st) {
      debugPrint('signOut error: $e');
      debugPrint('$st');
    }
  }
}
