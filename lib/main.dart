import 'dart:convert';
import 'dart:io'
    show
        InternetAddress,
        Platform,
        SocketException,
        File,
        Directory,
        HttpClient;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'dog.dart';
import 'welcome_page.dart';
import 'app_state.dart';
import 'notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'offers_manager.dart';
import 'package:barky_matches_fixed/firestore_recovery.dart';
import 'dart:async';
import 'ui/shell/nav_tab.dart';
import 'home_gate.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/dogs_box_manager.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_return_page.dart';
import 'package:barky_matches_fixed/ui/checkout/marketplace_checkout_return_page.dart';
import 'package:barky_matches_fixed/ui/checkout/marketplace_checkout_return_routing.dart';
import 'package:barky_matches_fixed/ui/creator/creator_dashboard_web_page.dart';
import 'package:barky_matches_fixed/services/firestore_readiness_gate.dart';
import 'package:barky_matches_fixed/services/fcm_token_service.dart';
import 'package:barky_matches_fixed/services/initial_notification_coordinator.dart';
import 'package:barky_matches_fixed/services/analytics/web_campaign_attribution.dart';
import 'package:barky_matches_fixed/services/web_auth_browser_info.dart';
import 'package:barky_matches_fixed/ui/business/business_partner_landing_page.dart';
import 'package:barky_matches_fixed/services/marketplace_order_notification_types.dart';
import 'package:barky_matches_fixed/services/business_finance_notification_types.dart';
import 'package:barky_matches_fixed/services/marketplace_service_notification_types.dart';
import 'package:barky_matches_fixed/services/appointment_notification_navigation_guard.dart';
import 'package:barky_matches_fixed/services/mobile_advertising_service.dart';
import 'package:barky_matches_fixed/services/web_advertising_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:app_links/app_links.dart';
import 'core/debug/auth_boot_trace.dart';
import 'core/debug/diagnostics_bootstrap.dart';
import 'core/debug/diagnostics_queue.dart';
import 'core/debug/diagnostics_uploader.dart';
import 'core/debug/web_startup_status.dart';
import 'developer_tools/developer_tools_page.dart';
import 'social/pages/social_post_route_page.dart';
import 'social/services/social_post_share.dart';

import 'ui/appointments/my_appointments_page.dart';
import 'ui/business/dashboard/vet/appointment_payment_page.dart';
import 'ui/orders/order_detail_page.dart';
import 'ui/chat/chat_detail_page.dart';

late Box<Dog> dogsBox;
late Box<Dog> favoritesBox;
late Box<String> currentUserBox;
late Box<String> userBox;
late Box<Map<dynamic, dynamic>> userDataBox;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _DeveloperToolsAccessDeniedPage extends StatefulWidget {
  const _DeveloperToolsAccessDeniedPage();

  @override
  State<_DeveloperToolsAccessDeniedPage> createState() =>
      _DeveloperToolsAccessDeniedPageState();
}

class _DeveloperToolsAccessDeniedPageState
    extends State<_DeveloperToolsAccessDeniedPage> {
  bool _shouldShowFallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      setState(() {
        _shouldShowFallback = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowFallback) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context)!.accessDenied,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  importance: Importance.max,
);

Future<void> clearHive() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${directory.path}/hive');
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
      if (kDebugMode) {
        debugPrint('Main - Cleared Hive directory: ${hiveDir.path}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Main - Error clearing Hive directory: $e');
    }
  }
}

Future<void> saveIosPushDebug({
  required String stage,
  String? apnsToken,
  String? fcmToken,
  String? error,
}) async {
  if (kIsWeb) return;

  try {
    await FirebaseFirestore.instance
        .collection('debug_tokens')
        .doc('ios_$stage')
        .set({
          'platform': Platform.isIOS ? 'ios' : 'other',
          'stage': stage,
          'apnsToken': apnsToken,
          'fcmToken': fcmToken,
          'error': error,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  } catch (_) {
    // intentionally silent (debug helper)
  }
}

Future<void> waitForInternet() async {
  final connectivity = Connectivity();

  for (int i = 0; i < 10; i++) {
    final result = await connectivity.checkConnectivity();

    final hasConnection = result.any((e) => e != ConnectivityResult.none);

    if (hasConnection) debugPrint('⏳ Waiting for internet... (${i + 1})');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  throw Exception('No internet connection detected');
}

/// Initializes (or attaches to an existing) default [FirebaseApp] using a
/// deterministic path that never depends on [Firebase.apps].
///
/// [Firebase.apps] on Web (`firebase_core_web`'s `FirebaseCoreWeb.apps`
/// getter, `firebase_core_web-3.3.1/lib/src/firebase_core_web.dart:229-245`)
/// calls `firebase_interop.getApps().toDart` — a JS-interop conversion whose
/// own try/catch only forgives JS-side `"... of undefined"` TypeErrors; it
/// has no defense against `dart:js_interop`'s own generated null-check
/// failing when the underlying JS array value isn't the shape it expects.
/// A prior fix wrapped that getter in a try/catch at the call site, but
/// that revision was never actually deployed (confirmed: production
/// `main.dart.js` still contains the old, pre-fix `"FIREBASE APP COUNT"`
/// probes), so it's still unproven — and per the "avoid the fragile getter
/// entirely" guidance, this version doesn't call [Firebase.apps] at all:
/// it calls [Firebase.initializeApp] unconditionally and uses its return
/// value directly, falling back to [Firebase.app] (a distinctly different,
/// already-defensive getter — see `firebase_core_web.dart`'s `app(name)`,
/// which translates `app/no-app` via its own try/catch) only for the
/// well-defined `duplicate-app` case.
Future<FirebaseApp> _initializeDefaultFirebaseApp(
  FirebaseOptions options,
) async {
  try {
    return await Firebase.initializeApp(options: options);
  } on FirebaseException catch (e, stackTrace) {
    if (e.code == 'duplicate-app') {
      return Firebase.app();
    }
    debugPrint(
      'Firebase.initializeApp() failed: '
      '${e.code}\n$stackTrace',
    );
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('Firebase.initializeApp() failed: $e\n$stackTrace');
    rethrow;
  }
}

Future<void> ensureFirebaseInitialized() async {
  final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
  await _initializeDefaultFirebaseApp(options);
  if (kIsWeb) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  }
  await _activateAppCheck();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  unawaited(
    FirebaseFirestore.instance
        .enableNetwork()
        .timeout(const Duration(seconds: 3))
        .then((_) {
          debugPrint('🌐 FIRESTORE NETWORK ENABLED → startup background');
        })
        .catchError((Object e) {
          debugPrint('🌐 FIRESTORE NETWORK ENABLE FAILED → $e');
        }),
  );
  FirestoreReadinessGate.instance.markFirebaseInitialized();
}

Future<void> _activateAppCheck() async {}

Future<void> ensureFirestoreReady() async {
  await FirestoreReadinessGate.instance.waitUntilReady(
    reason: 'main.ensureFirestoreReady',
  );
}

/*
Future<void> ensureFirestoreReady() async {
  int retries = 0;

  while (retries < 10) {
    try {
      await FirebaseFirestore.instance
          .collection('admin_logs') // 👈 collection واقعی خودت
          .limit(1)
          .get();

      print("🔥 Firestore CONNECTED");
      return;
    } catch (e) {
      print("⏳ retry ${retries + 1} → $e");
      await Future.delayed(Duration(seconds: 2 * (retries + 1)));
      retries++;
    }
  }

  print("❌ Firestore FAILED after retries");
}
*/
Future<T> retry<T>(Future<T> Function() run) async {
  var delay = const Duration(milliseconds: 500);

  for (var i = 0; i < 7; i++) {
    try {
      return await run();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 RETRY ${i + 1} FAILED → $e');
      }

      if (i == 6) rethrow;

      await Future.delayed(delay);
      delay *= 2;
    }
  }

  throw Exception('unreachable');
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FirestoreReadinessGate.instance.markFirstFrameReady();
  });

  final data = message.data;
  final user = FirebaseAuth.instance.currentUser;
}

Future<void> _firebaseMessagingForegroundHandler(RemoteMessage message) async {
  final data = message.data;
  final notification = message.notification;

  debugPrint("📩 Foreground message received → data=$data");
  final context = navigatorKey.currentContext;

  if (context == null) {
    debugPrint('🚫 No context → skip foreground notification');
    return;
  }

  final appState = context.read<AppState>();

  if (appState.isGuestUser) {
    debugPrint('🚫 Guest → skip foreground notification');
    return;
  }

  // 🔹 1️⃣ ذخیره در Firestore (اگر لازم)
  final user = FirebaseAuth.instance.currentUser;
  /*
  if (user != null && data.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': notification?.title ?? 'PetSupo',
        'body': notification?.body ?? '',
        'recipientUserId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'payload': Map<String, dynamic>.from(data),
      });

      debugPrint("✅ Foreground notification saved to Firestore");
    } catch (e) {
      debugPrint("❌ Error saving foreground notification: $e");
    }
  }
*/
  // 🔹 2️⃣ جلوگیری از duplicate در iOS
  // اگر iOS هست و message.notification وجود دارد،
  // سیستم خودش alert را نشان می‌دهد → local نساز
  if (kIsWeb) {
    debugPrint('🌐 Web push presentation handled by the browser');
    return;
  }

  if (Platform.isIOS && notification != null) {
    debugPrint(
      '🔔 Foreground handling path: iOS system presentation notification=${notification.title}',
    );
    debugPrint('🔔 Foreground sound enabled via presentation options');
    if ((data['type'] ?? '').toString().startsWith('pet_taxi_')) {
      debugPrint(
        '🚕 Playdate reference path detected: iOS notification payload uses system foreground presentation',
      );
      debugPrint(
        '🚕 Pet Taxi using same sound path: foreground presentation sound=true',
      );
    }
    debugPrint(
      "🍏 iOS system notification will handle display (no local show)",
    );
    return;
  }

  // 🔹 3️⃣ نمایش local notification (Android یا data-only)
  try {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // unique ID
      notification?.title ?? 'PetSopu',
      notification?.body ?? '',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );

    debugPrint("🔔 Local notification displayed");
    debugPrint("🔔 Foreground local notification shown");
    debugPrint("🔔 Sound enabled");
    if ((data['type'] ?? '').toString().startsWith('pet_taxi_')) {
      debugPrint("🚕 Pet Taxi foreground local notification shown");
      debugPrint("🚕 Pet Taxi sound enabled");
    }
    debugPrint("🔔 Foreground local notification sound enabled");
  } catch (e) {
    debugPrint("❌ Error showing local notification: $e");
  }
}

Future<bool> checkInternetConnection() async {
  try {
    final result = await InternetAddress.lookup(
      'dns.google',
    ).timeout(const Duration(seconds: 3));
    if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('Main - Internet connection detected via dns.google');
      }
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Main - Error checking internet connection: $e');
    }
  }

  try {
    final result = await InternetAddress.lookup(
      'firebaseappcheck.googleapis.com',
    ).timeout(const Duration(seconds: 3));
    if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Main - Internet connection detected via firebaseappcheck.googleapis.com',
        );
      }
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Main - Error checking firebaseappcheck.googleapis.com: $e');
    }
  }

  if (kDebugMode) {
    debugPrint('Main - No internet connection detected');
  }
  return false;
}

Future<void> testHttps() async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    final request = await client.getUrl(
      Uri.parse('https://securetoken.googleapis.com'),
    );

    final response = await request.close();
    debugPrint('✅ HTTPS OK → ${response.statusCode}');
    client.close(force: true);
  } catch (e) {
    debugPrint('❌ HTTPS FAIL → $e');
  }
}

Future<void> setupFCM() async {
  debugPrint('🌐 FCM INIT START');
  if (kIsWeb) {
    debugPrint('🌐 MOBILE FCM SETUP SKIPPED ON WEB');
    return;
  }

  final context = navigatorKey.currentContext;
  final appState = context?.read<AppState>();

  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    FcmTokenService.attachRefreshListener();
    _fcmForegroundSub ??= FirebaseMessaging.onMessage.listen(
      _firebaseMessagingForegroundHandler,
    );

    if (appState == null ||
        appState.isGuestUser ||
        appState.currentUserId == null) {
      debugPrint('🚫 Auth not ready/guest → skip FCM token save');
    } else {
      token = await FcmTokenService.generateAndSaveForCurrentUser(
        source: 'setupFCM',
      );
    }

    final settings = await messaging.getNotificationSettings();
    if (kDebugMode) {
      debugPrint(
        'Main - Notification permission status: ${settings.authorizationStatus}',
      );
    }

    // iOS Foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    debugPrint("🔔 Foreground FCM presentation sound enabled");

    String? apnsToken;

    if (Platform.isIOS) {
      await messaging.setAutoInitEnabled(true);

      if (kDebugMode) {
        debugPrint('iOS: AutoInit enabled');
      }

      for (int i = 0; i < 10; i++) {
        apnsToken = await messaging.getAPNSToken();
        debugPrint(
          '🌐 APNS TOKEN STATE → attempt=${i + 1} ready=${apnsToken != null && apnsToken.isNotEmpty}',
        );
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (apnsToken == null || apnsToken.isEmpty) {
        debugPrint("⚠️ APNS not ready");
      }
    }

    debugPrint('🌐 FCM TOKEN FETCH RESULT → ${token != null}');
    /*
    try {
      await retry(() => messaging.subscribeToTopic('all_users'));
      if (kDebugMode) {
        print('Main - Subscribed to topic: all_users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Main - Failed to subscribe to topic: $e');
      }
    }
*/

    _fcmMessageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      final context = navigatorKey.currentContext;

      if (context == null) return;

      final appState = context.read<AppState>();

      if (appState.isGuestUser) return;

      final data = message.data;
      final type = (data['type'] ?? '').toString();

      // 🔥 APPOINTMENT PAID
      if (type == 'appointment_paid' && data['appointmentId'] != null) {
        final appointmentId = data['appointmentId'].toString();

        debugPrint("💰 BACKGROUND TAP → $appointmentId");

        await _handleNotificationTapGuarded(
          appState,
          Map<String, dynamic>.from(data),
        );

        return;
      }

      if (type.startsWith('groomy_appointment_')) {
        await _handleNotificationTapGuarded(
          appState,
          Map<String, dynamic>.from(data),
        );
        return;
      }

      await _handleRemoteMessage(message);
    });

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final context = navigatorKey.currentContext;

        if (context == null) return;

        final appState = context.read<AppState>();

        if (appState.isGuestUser) {
          debugPrint('🚫 Guest → skip notification tap navigation');
          return;
        }

        if (kDebugMode) {
          debugPrint('Main - Notification clicked: $response');
        }

        if (response.payload == null) return;

        try {
          final payload = jsonDecode(response.payload!);

          final type = (payload['type'] ?? '').toString();

          if (type == 'chat_message') {
            await _openChatFromPayload(Map<String, dynamic>.from(payload));
            return;
          }

          if (AppointmentNotificationNavigationGuard.isAppointmentPayload(
            Map<String, dynamic>.from(payload),
          )) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }

          // ───────────────── APPOINTMENT PAID TAP 🔥 ─────────────────
          if (type == 'appointment_paid' && payload['appointmentId'] != null) {
            final appointmentId = payload['appointmentId'].toString();

            debugPrint("💰 TAP → OPEN APPOINTMENT $appointmentId");

            final appState = context.read<AppState>();
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );

            return;
          }

          if (type.startsWith('groomy_appointment_')) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }

          const petTaxiTypes = [
            'pet_taxi_booking_request',
            'pet_taxi_price_proposed',
            'pet_taxi_price_accepted',
            'pet_taxi_price_rejected',
            'pet_taxi_payment_success',
            'pet_taxi_payment_completed',
            'pet_taxi_driver_on_the_way',
            'pet_taxi_driver_arrived',
            'pet_taxi_pet_picked_up',
            'pet_taxi_trip_started',
            'pet_taxi_trip_completed',
            'pet_taxi_booking_cancelled',
            'pet_taxi_booking_cancelled_by_user',
            'pet_taxi_booking_response',
            'pet_taxi_status_update',
          ];

          if (petTaxiTypes.contains(type)) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }

          if (isMarketplaceOrderNotificationType(type)) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }
          if (isBusinessFinanceNotificationType(type)) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }
          if (isMarketplaceServiceNotificationType(type)) {
            await _handleNotificationTapGuarded(
              appState,
              Map<String, dynamic>.from(payload),
            );
            return;
          }
          /*
if ((type == 'playdateRequest' ||
     type == 'playdateResponse') &&
    payload['requestId'] != null) {

  final appState =
      navigatorKey.currentContext?.read<AppState>();

  if (appState != null) {
    appState.setInitialPlaydateRequest(
        payload['requestId'].toString());

    appState.setCurrentTab(NavTab.playdate);
  }

  return;
}

*/

          if ((type == 'like' || type == 'favorite') &&
              payload['likerUserId'] != null) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/user_profile',
              (route) => false,
              arguments: {'userId': payload['likerUserId']},
            );
            return;
          }

          if (type == 'lost_dog' && payload['lostDogId'] != null) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/lost_dogs_list',
              (route) => false,
            );
            return;
          }

          if (type == 'found_dog' && payload['foundDogId'] != null) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/found_dogs_list',
              (route) => false,
            );
            return;
          }

          //navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Main - Error handling notification click: $e');
          }
        }
      },
    );

    if (kDebugMode) {
      debugPrint(
        'Main - flutter_local_notifications initialized: $initialized',
      );
    }

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      if (kDebugMode) {
        debugPrint(
          'Main - Notification channel created: high_importance_channel',
        );
      }
    }

    bool? exactAlarmPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();

    if (kDebugMode) {
      debugPrint(
        'Main - Exact alarms permission granted: $exactAlarmPermissionGranted',
      );
    }

    if (exactAlarmPermissionGranted != true) {
      if (kDebugMode) {
        debugPrint(
          'Main - Warning: Exact alarms permission not granted. Notifications may not work as expected.',
        );
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Main - Error in setupFCM: $e');
    }
  }
}

String? token; // متغیر اصلی که باید آپدیت بشه
StreamSubscription<RemoteMessage>? _fcmMessageOpenedSub;
StreamSubscription<RemoteMessage>? _fcmForegroundSub;
StreamSubscription<User?>? _authFcmSub;
final InitialNotificationCoordinator _initialNotificationCoordinator =
    InitialNotificationCoordinator();

Future<void> _openChatFromPayload(Map<String, dynamic> payload) async {
  final chatId = (payload['chatId'] ?? payload['conversationId'] ?? '')
      .toString()
      .trim();
  final senderId = (payload['senderId'] ?? '').toString().trim();
  var senderName = (payload['senderName'] ?? 'Chat').toString().trim();

  if (chatId.isEmpty || senderId.isEmpty) {
    debugPrint('💬 Chat notification tap ignored: missing chatId/senderId');
    return;
  }

  if (senderName.isEmpty) {
    senderName = 'Chat';
  }

  final nav = navigatorKey.currentState;
  if (nav == null) {
    debugPrint('💬 Chat notification tap ignored: navigator unavailable');
    return;
  }

  nav.push(
    MaterialPageRoute(
      builder: (_) => ChatDetailPage(
        chatId: chatId,
        otherUserId: senderId,
        otherUserName: senderName,
      ),
    ),
  );
}

Future<void> _initializeNotificationsAfterStartup(AppState appState) async {
  if (kIsWeb) {
    debugPrint('🌐 MOBILE NOTIFICATION INIT SKIPPED ON WEB');
    return;
  }

  if (appState.isGuestUser || !appState.authUserDetected) {
    debugPrint('🌐 NOTIFICATION INIT DELAYED → waiting for auth user');
    return;
  }

  debugPrint('🌐 NOTIFICATION INIT DELAYED → first frame/auth detected');
  await Future.delayed(const Duration(milliseconds: 750));

  try {
    await NotificationService().init();
    token = await FcmTokenService.generateAndSaveForCurrentUser(
      source: 'notification_init',
    );
    debugPrint('🌐 NOTIFICATION INIT COMPLETE');
    debugPrint("🔥 FCM token initialized: ${token != null}");
  } catch (e) {
    debugPrint('🌐 NOTIFICATION INIT FAILED → $e');
  }
}

Future<void> _handleRemoteMessage(RemoteMessage message) async {
  await _handleRemoteMessageData(Map<String, dynamic>.from(message.data));
}

Future<AppointmentNotificationNavigationDecision> _handleNotificationTapGuarded(
  AppState appState,
  Map<String, dynamic> payload,
) {
  final context = navigatorKey.currentContext;
  final l10n = context == null ? null : AppLocalizations.of(context);
  void showMessage(String? message) {
    if (context == null || message == null) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  return appState.handleNotificationTapGuarded(
    payload,
    onMissingOrMalformed: () {
      showMessage(l10n?.appointmentNoLongerAvailable);
    },
    onLookupFailedOrUnresolved: () {
      showMessage(l10n?.appointmentAvailabilityCheckFailed);
    },
  );
}

Future<void> _handleRemoteMessageData(
  Map<String, dynamic> data, {
  bool retryUnresolvedAppointment = false,
}) async {
  final type = (data['type'] ?? '').toString();

  debugPrint("🟨 HANDLE REMOTE MESSAGE: $data");

  final appState = navigatorKey.currentContext?.read<AppState>();

  if (appState == null || appState.isGuestUser) {
    debugPrint('🚫 Guest/no appState → skip remote message navigation');
    return;
  }

  if ((type == 'playdate_request' || type == 'playdate_response') &&
      data['requestId'] != null) {
    appState.ignoreNextNotificationTap(); // ✅ این خط اصلاح شد

    appState.setInitialPlaydateRequest(data['requestId'].toString());
    appState.setCurrentTab(NavTab.playdate);
  }

  if (type == 'chat_message') {
    await _openChatFromPayload(Map<String, dynamic>.from(data));
    return;
  }

  Future<void> guardAppointmentTap(Map<String, dynamic> payload) async {
    final decision = await _handleNotificationTapGuarded(appState, payload);
    if (retryUnresolvedAppointment &&
        decision ==
            AppointmentNotificationNavigationDecision
                .lookupFailedOrUnresolved) {
      throw const InitialNotificationRetryableFailure(
        'appointment_lookup_unresolved',
      );
    }
  }

  if (AppointmentNotificationNavigationGuard.isAppointmentPayload(data)) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }

  // ───────────────── APPOINTMENT PAID 🔥 ─────────────────
  if (type == 'appointment_paid' && data['appointmentId'] != null) {
    final appointmentId = data['appointmentId'].toString();

    debugPrint("💰 AUTO OPEN APPOINTMENT → $appointmentId");

    appState.ignoreNextNotificationTap();

    await guardAppointmentTap(Map<String, dynamic>.from(data));

    return;
  }

  if (type.startsWith('groomy_appointment_')) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }

  const petTaxiTypes = [
    'pet_taxi_booking_request',
    'pet_taxi_payment_completed',
    'pet_taxi_booking_cancelled_by_user',
    'pet_taxi_price_proposed',
    'pet_taxi_payment_success',
    'pet_taxi_driver_on_the_way',
    'pet_taxi_driver_arrived',
    'pet_taxi_pet_picked_up',
    'pet_taxi_trip_started',
    'pet_taxi_trip_completed',
    'pet_taxi_booking_cancelled',
    'pet_taxi_status_update',
  ];

  if (petTaxiTypes.contains(type)) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }

  if (isMarketplaceOrderNotificationType(type)) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }

  if (isBusinessFinanceNotificationType(type)) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }

  if (isMarketplaceServiceNotificationType(type)) {
    await guardAppointmentTap(Map<String, dynamic>.from(data));
    return;
  }
}

InitialNotificationReadiness _initialNotificationReadiness() {
  final context = navigatorKey.currentContext;
  final appState = context?.read<AppState>();
  final uid = appState?.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

  return InitialNotificationReadiness(
    navigatorReady: navigatorKey.currentState != null && context != null,
    appStateReady: appState?.isUserProfileReady ?? false,
    authReady: appState?.authUserDetected ?? false,
    isGuest: appState?.isGuestUser ?? true,
    currentUserId: uid,
  );
}

Future<void> _processPendingInitialNotification() {
  return _initialNotificationCoordinator.processPendingIfReady(
    readiness: _initialNotificationReadiness(),
    handle: (data) =>
        _handleRemoteMessageData(data, retryUnresolvedAppointment: true),
  );
}

Future<void> _retrieveInitialNotificationOnce() {
  return _initialNotificationCoordinator.retrieveOnce(
    getInitialMessage: () async {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) return null;
      return InitialNotificationMessage(
        messageId: message.messageId,
        data: Map<String, dynamic>.from(message.data),
      );
    },
    readiness: _initialNotificationReadiness(),
    handle: (data) =>
        _handleRemoteMessageData(data, retryUnresolvedAppointment: true),
  );
}

void main() async {
  final initialUri = kIsWeb ? Uri.base : null;
  final initialReferrer = kIsWeb
      ? webRedirectDiagnosticSnapshot()['referrer']?.toString()
      : null;

  // Development diagnostics remain available locally, but the production
  // client must not expose Firestore documents, IDs, or debug state in the
  // browser/device console.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  if (kDebugMode) {
    debugPrint('Main - Starting main function...');
  }

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
  } catch (e, stackTrace) {
    debugPrint('Hive.initFlutter() failed: $e\n$stackTrace');
    rethrow;
  }

  DiagnosticsQueue().enablePersistence();
  await DiagnosticsBootstrap.initialize();

  // Durable cold-start auth trace. Opened before Firebase so the restore
  // interval — which is over before `flutter logs` can attach — is captured.
  await AuthBootTrace.initialize();
  GoogleFonts.config.allowRuntimeFetching = true;
  //await waitForInternet();
  AuthBootTrace.record('firebase_init_start');
  await ensureFirebaseInitialized();
  AuthBootTrace.recordCurrentUserSnapshot('after_firebase_init');
  if (!kIsWeb) {
    unawaited(
      MobileAdvertisingService.instance.initialize(
        source: 'foreground_startup',
      ),
    );
  }
  if (initialUri != null) {
    await WebCampaignAttribution.recordInitialUtmCampaignWithFirebase(
      initialUri,
      referrer: initialReferrer,
    );
  }
  FcmTokenService.attachRefreshListener();
  _authFcmSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null || user.isAnonymous) {
      debugPrint('🔥 FCM AUTH LISTENER: signed out');
      return;
    }

    debugPrint('🔥 FCM AUTH LISTENER: authenticated ${user.uid}');
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500)).then((_) async {
        token = await FcmTokenService.generateAndSaveForCurrentUser(
          source: 'auth_state',
        );
      }),
    );
  });
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  _fcmForegroundSub ??= FirebaseMessaging.onMessage.listen(
    _firebaseMessagingForegroundHandler,
  );
  //await FirebaseAuth.instance.signOut();
  //await AuthTrap.signOut(reason: 'manual_logout');

  // 👇 این خط جدید (اینجااااا)
  //await FirebaseAuth.instance.authStateChanges().first;

  // 🔥 wait until Firestore actually ready (real gate)

  //await testHttps();

  // 🔥 INTERNET TEST
  //final hasInternet = await checkInternetConnection();
  //print("🌐 INTERNET STATUS = $hasInternet");
  // if (kDebugMode) {
  // await clearHive();
  //}

  debugPrint('🌐 NOTIFICATION INIT DELAYED → startup auth gate not ready');

  Hive.registerAdapter(DogAdapter());

  final dogsBoxFuture = Hive.openBox<Dog>('dogsBox');
  final favoritesBoxFuture = Hive.openBox<Dog>('favoritesBox');
  final currentUserBoxFuture = Hive.openBox<String>('currentUserBox');
  final userBoxFuture = Hive.openBox<String>('userBox');
  final userDataBoxFuture = Hive.openBox<Map<dynamic, dynamic>>('userDataBox');

  unawaited(
    dogsBoxFuture
        .then((box) {
          dogsBox = box;
          DogsBoxManager.instance.attach(dogsBox);

          if (kDebugMode) {
            debugPrint(
              'Main - Hive initialized, dogsBox size: ${dogsBox.length}',
            );
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          DogsBoxManager.instance.markError(error, stackTrace);
          debugPrint('Main - Error opening dogsBox: $error');
        }),
  );

  favoritesBox = await favoritesBoxFuture;
  currentUserBox = await currentUserBoxFuture;
  userBox = await userBoxFuture;
  userDataBox = await userDataBoxFuture;

  List<Dog> firestoreDogs = [];
  final favoriteDogs = favoritesBox.isOpen
      ? favoritesBox.values.cast<Dog>().toList()
      : <Dog>[];

  if (kDebugMode) {
    debugPrint('Main - Initial favorite dogs count: ${favoriteDogs.length}');
    debugPrint('Main - firestoreDogs count: ${firestoreDogs.length}');
  }

  Future<void> initializeAsync() async {
    final context = navigatorKey.currentContext;
    var authGateOpen = context == null;
    int? startupGeneration;

    if (context != null) {
      for (int i = 0; i < 80; i++) {
        if (!context.mounted) return;
        final appState = context.read<AppState>();
        final uid =
            appState.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

        if (appState.isUserProfileReady &&
            (appState.isGuestUser || (uid != null && uid.isNotEmpty))) {
          debugPrint('✅ Startup auth gate open → uid=$uid');
          startupGeneration = appState.startupSessionGeneration;
          authGateOpen = true;
          break;
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    if (!authGateOpen) {
      debugPrint(
        '⚠️ Startup auth gate did not open; deferring Firestore reads',
      );
      return;
    }

    final appState = navigatorKey.currentContext?.read<AppState>();
    if (appState != null) {
      startupGeneration ??= appState.startupSessionGeneration;
      await _initializeNotificationsAfterStartup(appState);
    }

    final noncriticalReady =
        await appState?.waitForNoncriticalReadsAllowed(
          timeout: const Duration(seconds: 25),
          generation: startupGeneration,
        ) ??
        false;

    if (appState != null &&
        startupGeneration != null &&
        startupGeneration != appState.startupSessionGeneration) {
      debugPrint('🌐 STARTUP WATCHDOG CANCELLED → stale async callback');
      return;
    }

    if (!noncriticalReady) {
      if (appState?.startupSuccessFinalized == true) {
        debugPrint('🌐 STARTUP SUCCESS PATH FINALIZED');
        return;
      }
      debugPrint('🌐 STARTUP DEGRADED MODE → main noncritical reads deferred');
      return;
    }

    final firestoreReady = await FirestoreReadinessGate.instance.waitUntilReady(
      reason: 'main startup critical reads',
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
    if (!firestoreReady) {
      debugPrint('🌐 STARTUP DEGRADED MODE → Firestore gate unavailable');
      return;
    }

    final offersStartupReady =
        appState != null &&
        (appState.authUserDetected || appState.isGuest) &&
        appState.noncriticalReadsAllowed &&
        appState.startupSuccessFinalized;

    await OffersManager.loadOffersOnce(
      startupReady: offersStartupReady,
      recoveryScope: FirestoreRecoveryScope.startup,
    );
    await setupFCM();
    await _retrieveInitialNotificationOnce();
    await _processPendingInitialNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_processPendingInitialNotification());
    });
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Flutter's first frame has now painted — hide the web startup safety
    // net overlay (web/index.html). No-op on non-web platforms.
    hideWebStartupStatus();
    unawaited(initializeAsync());
  });

  if (false) {
    AuthTrap.signOut(reason: 'session_expired');
  } // 👈 فقط برای تست

  // Resolve the startup language before the first frame: saved choice, else
  // device locale, else English. Doing this here (rather than after runApp)
  // means the app never paints English first and then switches.
  final String initialLanguageCode = await AppState.loadInitialLanguageCode();

  // Emitted again after launch so the operator can attach `flutter logs`
  // once the app has already reached its startup destination.
  AuthBootTrace.scheduleDumps();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MobileAdvertisingService>.value(
          value: MobileAdvertisingService.instance,
        ),
        ChangeNotifierProvider<WebAdvertisingService>.value(
          value: WebAdvertisingService.instance,
        ),
        ChangeNotifierProvider<AppState>(
          create: (context) {
            final appState = AppState(
              favoriteDogs: favoriteDogs,

              favoriteDogsNotifier: ValueNotifier<List<Dog>>(favoriteDogs),

              likesNotifier: ValueNotifier<Map<String, List<String>>>({}),

              onToggleFavorite: (Dog dog) async {
                await Provider.of<AppState>(
                  context,
                  listen: false,
                ).toggleFavorite(dog);
              },

              notificationService: NotificationService(),

              initialLanguageCode: initialLanguageCode,
            );

            if (!kIsWeb) {
              IapService.instance.setSubscriptionActivatedCallback(() async {
                await appState.loadSubscriptionFromFirestore();

                debugPrint('🔄 UI refreshed');

                await Future.delayed(const Duration(milliseconds: 500));

                appState.openProfileSubPage(ProfileSubPage.businessRegister);
              });
            }

            appState.markFirebaseInitialized();

            // ❗️ خیلی مهم: فقط این
            if (kIsWeb) {
              scheduleMicrotask(appState.startAuthListener);
            } else {
              appState.startAuthListener();
            }
            // AuthTrap.start();
            // AuthTrap.scheduleTokenDiagnostics();
            if (!kIsWeb) {
              IapService.instance.setSubscriptionActivatedCallback(() async {
                await appState.loadSubscriptionFromFirestore();
                debugPrint('🔄 UI refreshed');
              });
            }

            return appState;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
  debugPrint('🧨 startAuthListener fired');
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // طبق خواسته‌ات: همیشه اول Welcome (Greeting)
    return const WelcomePage();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  /*
  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<State<MyApp>>();
    state?.setState(() {
      (state as MyAppState)._locale = newLocale;
    });
  }
*/
  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _lastHandledLink;
  Uri? _pendingPostLink;
  final DiagnosticsUploader _diagnosticsUploader = DiagnosticsUploader();
  AppState? _appState;

  //Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLinkOnce(uri, "INITIAL LINK");
      }
    });

    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLinkOnce(uri, "DEEP LINK RECEIVED");
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushPendingPostLink();
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerDiagnosticsUpload();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  void _handleDeepLinkOnce(Uri uri, String label) {
    if (_lastHandledLink == uri) return;
    _lastHandledLink = uri;
    debugPrint("$label: $uri");
    handleDeepLink(uri);
  }

  void _flushPendingPostLink() {
    final uri = _pendingPostLink;
    if (uri == null) return;
    _pendingPostLink = null;
    _openPostDeepLink(uri);
  }

  void _openPostDeepLink(Uri uri) {
    final postId = SocialPostShare.postIdFromDeepLink(uri);
    if (postId == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingPostLink = uri;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushPendingPostLink();
      });
      return;
    }

    navigator.push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/post/$postId'),
        builder: (_) =>
            SocialPostRoutePage(postId: postId, openedFromExternalShare: true),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _appState = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('🔄 App resumed');

      final appState = _appState;
      if (appState == null) return;

      appState.ignoreNotificationIconTapFor(const Duration(milliseconds: 600));
      _triggerDiagnosticsUpload();
    }
  }

  void _triggerDiagnosticsUpload() {
    unawaited(
      _diagnosticsUploader.uploadPendingReports().catchError((Object _) {
        return;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.select<AppState, Locale>((state) => state.locale);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      onTap: () {
        final currentFocus = FocusManager.instance.primaryFocus;

        if (currentFocus != null && !currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[],
        theme: AppTheme.theme(locale: locale),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routes: <String, WidgetBuilder>{
          '/orderDetail': (context) => OrderDetailPage(
            sellerOrderId: ModalRoute.of(context)!.settings.arguments as String,
          ),
          '/appointmentPayment': (context) => AppointmentPaymentPage(
            appointmentId: ModalRoute.of(context)!.settings.arguments as String,
          ),
          if (kDebugMode)
            '/developerTools': (context) {
              final AppState appState = context.read<AppState>();
              if (!appState.isAdmin) {
                return const _DeveloperToolsAccessDeniedPage();
              }

              return const DeveloperToolsPage();
            },
        },
        home:
            _webPaymentReturnPage() ??
            _webCreatorDashboardPage() ??
            _webPostPage() ??
            _webBusinessPartnerLandingPage() ??
            const WebAuthStartupGate(child: AppEntry()),
      ),
    );
  }

  // İş Bank's 3-D Secure browser redirect lands here for BOTH Web
  // subscription orders and marketplace (Pet Shop) orders — both flows
  // share the same backend callback (`isbank3DSuccessReturn` /
  // `isbank3DFailReturn`, see functions/index.js's webSubscriptionBrowserReturn),
  // which only ever knows an orderId, not an order type. Order IDs for
  // web_subscription orders are always generated with a `websub_` prefix
  // (webSubscriptionOrderId() in functions/index.js); every other order id
  // reaching this route is a marketplace order using its own authoritative
  // order/finalization schema. Routing here — not inside either return
  // page — is what keeps the two flows from being conflated.
  Widget? _webPaymentReturnPage() {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    final returnKind = uri.queryParameters['webSubscriptionReturn'];
    final isReturnPath =
        uri.path == '/isbank/3d-success' || uri.path == '/isbank/3d-fail';
    if (!isReturnPath && returnKind != 'success' && returnKind != 'fail') {
      return null;
    }
    final orderId = uri.queryParameters['oid'] ?? '';
    final resolvedKind = returnKind == 'fail' ? 'fail' : 'success';

    if (isWebSubscriptionOrderId(orderId)) {
      return WebSubscriptionReturnPage(
        orderId: orderId,
        returnPath: resolvedKind == 'fail' ? '/isbank/3d-fail' : uri.path,
      );
    }
    return MarketplaceCheckoutReturnPage(
      orderId: orderId,
      returnKind: resolvedKind,
    );
  }

  // The full Web Creator Dashboard — reached when a signed-in, approved
  // creator taps "Open Full Dashboard" in the lightweight mobile page
  // (lib/ui/creator/creator_dashboard_page.dart). On Web this is a same-tab,
  // same-origin navigation (see resolveCreatorDashboardNavigation /
  // openCreatorDashboardSameTab) so the Firebase Auth session survives; on
  // iOS/Android it instead opens app.petsupo.com/creator/dashboard in an
  // external browser. CreatorDashboardWebPage itself gates on auth +
  // AppState.creatorEnabled, the same way user_profile_page.dart's
  // businessDashboard branch gates on hasApprovedBusiness — see
  // lib/ui/creator/creator_dashboard_web_page.dart.
  Widget? _webCreatorDashboardPage() {
    if (!kIsWeb) return null;
    if (Uri.base.path != '/creator/dashboard') return null;
    return const CreatorDashboardWebPage();
  }

  Widget? _webPostPage() {
    if (!kIsWeb) return null;
    final postId = SocialPostShare.postIdFromUri(Uri.base);
    if (postId == null) return null;
    return SocialPostRoutePage(postId: postId, openedFromExternalShare: true);
  }

  Widget? _webBusinessPartnerLandingPage() {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    final partnerCategory = WebCampaignAttribution.partnerCategoryForPath(
      uri.path,
    );
    if (partnerCategory == null) return null;
    return WebAuthStartupGate(
      child: BusinessPartnerLandingPage(
        partnerCategory: partnerCategory,
        initialSector: WebCampaignAttribution.initialSectorForPartnerCategory(
          partnerCategory,
        ),
      ),
    );
  }

  void handleDeepLink(Uri uri) async {
    if (kDebugMode) {
      debugPrint("🔗 DEEP LINK RECEIVED: ${uri.scheme}://${uri.host}");
    }

    final postId = SocialPostShare.postIdFromDeepLink(uri);
    if (postId != null) {
      _openPostDeepLink(uri);
      return;
    }

    /// فقط payment success
    if (uri.host != "payment-success") return;

    final orderId = uri.queryParameters["orderId"];

    if (kDebugMode) {
      debugPrint(
        "🔥 VERIFY ORDER ID FROM DEEPLINK: ${orderId != null && orderId.isNotEmpty}",
      );
    }

    if (orderId == null || orderId.isEmpty) {
      debugPrint("❌ ORDER ID NULL OR EMPTY");
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('verifyPayment');

      Map<String, dynamic>? data;

      /// 🔁 retry (max 5)
      for (int i = 0; i < 5; i++) {
        debugPrint("🔁 VERIFY TRY: $i");

        await Future.delayed(const Duration(seconds: 2));

        if (kDebugMode) {
          debugPrint("🚀 SENDING PAYMENT VERIFY REQUEST");
        }

        final res = await callable.call({"orderId": orderId});

        if (kDebugMode) {
          debugPrint("✅ VERIFY RESULT RECEIVED");
        }

        data = Map<String, dynamic>.from(res.data);

        /// اگر هنوز pending → retry
        if (data["pending"] == true) continue;

        break;
      }

      /// ❌ هیچ data نگرفتیم
      if (data == null) {
        debugPrint("❌ VERIFY FAILED COMPLETELY");
        return;
      }

      /// ❌ پرداخت موفق نیست
      if (data["success"] != true) {
        debugPrint("❌ PAYMENT NOT SUCCESS");
        return;
      }

      final paymentType = (data["type"] ?? data["orderType"] ?? "").toString();
      final appointmentId = (data["appointmentId"] ?? "").toString();
      final appointmentCollection =
          (data["appointmentCollection"] ?? "vet_appointments").toString();
      final isHotelBooking =
          appointmentCollection == "hotel_bookings" ||
          (data["appointmentType"] ?? "").toString() == "pet_hotel";
      final isGroomyAppointment =
          appointmentCollection == "groomy_appointments" ||
          (data["appointmentType"] ?? "").toString() == "grooming";
      final isAppointmentPayment =
          paymentType == "appointment" || appointmentId.isNotEmpty;

      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint("❌ CONTEXT NULL");
        return;
      }

      if (isAppointmentPayment) {
        debugPrint("🩺 OPEN APPOINTMENT AFTER PAYMENT → $appointmentId");

        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeGate()),
          (route) => false,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => appointmentId.isNotEmpty
                ? AppointmentPaymentPage(
                    appointmentId: appointmentId,
                    appointmentCollection: appointmentCollection,
                    appointmentType: isHotelBooking
                        ? "pet_hotel"
                        : isGroomyAppointment
                        ? "grooming"
                        : "veterinary",
                    updateStatusFunctionName: isHotelBooking
                        ? "updateHotelBookingStatus"
                        : isGroomyAppointment
                        ? "updateGroomyAppointmentStatus"
                        : "updateVetAppointmentStatus",
                    createOrderFunctionName: isHotelBooking
                        ? "createHotelBookingOrder"
                        : "createAppointmentOrder",
                    verifyPaymentFunctionName: isHotelBooking
                        ? "verifyHotelBookingPayment"
                        : "verifyPayment",
                    serviceFallbackName: isHotelBooking
                        ? "Hotel stay"
                        : isGroomyAppointment
                        ? "Grooming service"
                        : "Veterinary service",
                    businessFallbackName: isHotelBooking
                        ? "Pet hotel"
                        : isGroomyAppointment
                        ? "Grooming studio"
                        : "Vet clinic",
                    businessInfoLabel: isHotelBooking
                        ? "Hotel"
                        : isGroomyAppointment
                        ? "Groomy"
                        : "Clinic",
                  )
                : const MyAppointmentsPage(),
          ),
        );
        return;
      }

      /// 📦 seller orders
      final List sellerOrderIds = (data["sellerOrderIds"] ?? []) as List;

      if (sellerOrderIds.isEmpty) {
        debugPrint("❌ NO SELLER ORDERS");
        return;
      }

      /// 🔥 فعلاً اولین seller (later: multi-seller UI)
      final sellerOrderId = sellerOrderIds.first.toString();

      if (kDebugMode) {
        debugPrint("📦 OPEN SELLER ORDER");
      }

      if (!context.mounted) return;

      /// 🏠 reset navigation stack
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeGate()),
        (route) => false,
      );

      /// ⏳ صبر برای stable navigation
      await Future.delayed(const Duration(milliseconds: 500));

      /// 📦 رفتن به order detail (sellerOrderId ✅)
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(sellerOrderId: sellerOrderId),
        ),
      );
    } catch (e, stack) {
      debugPrint("❌ VERIFY ERROR: $e");
      debugPrint("📛 STACK: $stack");
    }
  }
}
