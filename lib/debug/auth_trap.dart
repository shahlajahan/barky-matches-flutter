import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthTrap {
  AuthTrap._();

  static bool _started = false;
  static String? lastMarker;

  /// Call this ONCE after Firebase.initializeApp()
  static void start() {
    if (_started) return;
    _started = true;

    debugPrint('🧨 AuthTrap.start()');

    FirebaseAuth.instance.userChanges().listen((user) {
      final now = DateTime.now().toIso8601String();

      debugPrint(
          '🧨 [AuthTrap] userChanges @ $now -> ${user?.uid ?? "NULL"} | marker=$lastMarker');

      if (user == null) {
        debugPrint('🚨🚨🚨 USER BECAME NULL 🚨🚨🚨 marker=$lastMarker');
        debugPrintStack(label: '🧨 AuthTrap user NULL stack');
      }
    }, onError: (e, s) {
      debugPrint('🧨 AuthTrap userChanges ERROR: $e');
      debugPrint('$s');
    });
  }

  static void mark(String tag) {
    lastMarker = tag;
    debugPrint('🧨 AuthTrap MARK -> $tag | uid=${FirebaseAuth.instance.currentUser?.uid}');
  }

  static Future<void> signOut({required String reason}) async {
    debugPrint(
        '🧨 AuthTrap SIGNOUT CALLED -> reason=$reason | uid=${FirebaseAuth.instance.currentUser?.uid}');
    debugPrintStack(label: '🧨 AuthTrap signOut stack');
    await FirebaseAuth.instance.signOut();
  }
}