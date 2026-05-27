import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const bool verboseStartupLogs = false;

class FirestoreReadinessGate {
  FirestoreReadinessGate._();

  static final FirestoreReadinessGate instance = FirestoreReadinessGate._();

  bool _firebaseInitialized = false;

  String? _authUid;

  void reset({String reason = 'reset'}) {
    _authUid = null;

    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE GATE RESET → $reason');
    }
  }

  void markFirebaseInitialized() {
    _firebaseInitialized = true;

    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE GATE → firebase initialized');
    }
  }

  void markFirstFrameReady() {
    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE GATE → first frame ready');
    }
  }

  void markAuthStabilized(String? uid) {
    _authUid = (uid == null || uid.trim().isEmpty) ? 'guest' : uid.trim();

    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE GATE → auth stabilized uid=$_authUid');
    }
  }

  Future<bool> waitUntilReady({
    String reason = 'Firestore read',
    String? uid,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_firebaseInitialized) {
      if (kDebugMode && verboseStartupLogs) {
        debugPrint('🌐 FIRESTORE GATE WAIT → firebase init ($reason)');
      }

      await _waitFor(() => _firebaseInitialized);
    }

    final resolvedUid = _resolveUid(uid);

    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE GATE PASSIVE OPEN → $reason uid=$resolvedUid');
    }

    return true;
  }

  Future<T> runSerial<T>(
    String operationName,
    Future<T> Function() operation, {
    String? uid,
  }) async {
    if (kDebugMode && verboseStartupLogs) {
      debugPrint('🌐 FIRESTORE SERIAL PASS-THROUGH → $operationName');
    }

    return operation();
  }

  String _resolveUid(String? uid) {
    final direct = uid?.trim();

    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final current = FirebaseAuth.instance.currentUser?.uid.trim();

    if (current != null && current.isNotEmpty) {
      return current;
    }

    return _authUid ?? 'guest';
  }

  Future<void> _waitFor(bool Function() predicate) async {
    for (int i = 0; i < 30; i++) {
      if (predicate()) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
