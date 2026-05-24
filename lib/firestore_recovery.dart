import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FirestoreRecoveryScope { startup, background }

class FirestoreRecovery {
  static bool passiveMode = true;
  static const Duration startupRetrySuppressionWindow = Duration(seconds: 90);
  static DateTime? _recoveryCooldownUntil;

  static bool get isRecoveryActive => false;

  static bool get isRecoveryCooldownActive {
    final until = _recoveryCooldownUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _recoveryCooldownUntil = null;
    return false;
  }

  static Duration get recoveryCooldownRemaining {
    final until = _recoveryCooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining <= Duration.zero ? Duration.zero : remaining;
  }

  static bool isConnectivityError(Object error) {
    if (error is FirebaseException && error.code == 'unavailable') {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('unavailable') ||
        message.contains('could not reach cloud firestore backend') ||
        message.contains('watchstream') ||
        message.contains('internal error') ||
        message.contains('offline mode');
  }

  static void deferPassiveRetry([String reason = 'startup unavailable']) {
    _recoveryCooldownUntil = DateTime.now().add(startupRetrySuppressionWindow);
    debugPrint('🌐 PASSIVE RETRY DEFERRED → $reason');
    debugPrint(
      '🌐 FIRESTORE RECOVERY COOLDOWN → '
      '${startupRetrySuppressionWindow.inSeconds}s',
    );
  }

  // No active recovery loop. Firestore network state is managed once at app
  // startup; reads should fail visibly instead of toggling the SDK offline.
}
