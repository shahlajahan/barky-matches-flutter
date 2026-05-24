import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenService {
  FcmTokenService._();

  static StreamSubscription<String>? _refreshSub;

  static Future<String?> generateAndSaveForCurrentUser({
    String source = 'manual',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('🔥 FCM TOKEN SKIPPED: no authenticated user ($source)');
        return null;
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '🔥 FCM PERMISSION STATUS: ${settings.authorizationStatus} ($source)',
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔥 Foreground FCM presentation sound enabled');

      if (Platform.isIOS) {
        String? apnsToken;
        for (int attempt = 0; attempt < 10; attempt++) {
          apnsToken = await messaging.getAPNSToken();
          debugPrint(
            '🔥 APNS TOKEN STATE: attempt=${attempt + 1} ready=${apnsToken != null && apnsToken.isNotEmpty}',
          );
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        debugPrint(
          '🔥 APNS TOKEN READY: ${apnsToken != null && apnsToken.isNotEmpty}',
        );
      }

      final token = await messaging.getToken();
      debugPrint('🔥 FCM TOKEN GENERATED: $token');
      debugPrint('🔥 FCM TOKEN LENGTH: ${token?.length}');

      if (token == null || token.isEmpty) {
        debugPrint('🔥 FCM TOKEN SAVE SKIPPED: empty token ($source)');
        return null;
      }

      await _saveToken(uid: user.uid, token: token, source: source);
      return token;
    } catch (e) {
      debugPrint('🔥 FCM TOKEN INIT FAILED ($source): $e');
      return null;
    }
  }

  static void attachRefreshListener() {
    if (_refreshSub != null) return;

    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('🔥 FCM TOKEN REFRESH: $newToken');
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint('🔥 FCM TOKEN REFRESH SAVE SKIPPED: no user');
          return;
        }

        try {
          await _saveToken(
            uid: user.uid,
            token: newToken,
            source: 'token_refresh',
          );
        } catch (e) {
          debugPrint('🔥 FCM TOKEN REFRESH SAVE FAILED: $e');
        }
      },
      onError: (Object e) {
        debugPrint('🔥 FCM TOKEN REFRESH LISTENER ERROR: $e');
      },
    );
  }

  static Future<void> _saveToken({
    required String uid,
    required String token,
    required String source,
  }) async {
    debugPrint('🔥 FCM TOKEN SAVE START');
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await userDocRef.set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'fcmTokenSource': source,
    }, SetOptions(merge: true));

    final userDoc = await userDocRef.get();
    final savedToken = userDoc.data()?['fcmToken']?.toString();
    if (savedToken != token) {
      throw StateError('FCM token Firestore verification failed');
    }

    debugPrint('🔥 FCM TOKEN SAVE SUCCESS');

    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('syncBusinessToken').call({'token': token});
      debugPrint('🔥 FCM BUSINESS TOKEN SYNC SUCCESS');
    } catch (e) {
      debugPrint('🔥 FCM BUSINESS TOKEN SYNC FAILED: $e');
    }
  }
}
