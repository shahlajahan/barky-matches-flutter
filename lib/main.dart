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
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/services/firestore_readiness_gate.dart';
import 'package:barky_matches_fixed/services/fcm_token_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:app_links/app_links.dart';

import 'package:uni_links/uni_links.dart';
import 'ui/appointments/my_appointments_page.dart';
import 'ui/business/dashboard/vet/appointment_payment_page.dart';

import 'ui/orders/order_detail_page.dart';
import 'ui/chat/chat_detail_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

late Box<Dog> dogsBox;
late Box<Dog> favoritesBox;
late Box<String> currentUserBox;
late Box<String> userBox;
late Box<Map<dynamic, dynamic>> userDataBox;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

Future<void> ensureFirebaseInitialized() async {
  debugPrint('🌐 FIREBASE INIT START');
  debugPrint('🌐 FIREBASE APP COUNT → before=${Firebase.apps.length}');
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🌐 Firebase.initializeApp executed from Dart');
  } else {
    debugPrint('🌐 Firebase.initializeApp skipped; existing app detected');
  }

  debugPrint('🌐 FIREBASE APP COUNT → after=${Firebase.apps.length}');
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
  debugPrint('🌐 FIRESTORE INSTANCE CREATED → settings configured');
  FirestoreReadinessGate.instance.markFirebaseInitialized();

  debugPrint("🔥 Firebase initialized");

  debugPrint('🌐 FIREBASE INIT COMPLETE');
  debugPrint('🔥 Firebase ready');
}

Future<void> _activateAppCheck() async {
  debugPrint('🌐 APP CHECK TEMP DISABLED');
}

void logStartupEnvironmentDiagnostics() {
  if (kDebugMode) {
    debugPrint('🌐 DEBUG MODE DETECTED');
  } else if (kProfileMode) {
    debugPrint('🌐 PROFILE MODE DETECTED');
  } else if (kReleaseMode) {
    debugPrint('🌐 RELEASE MODE DETECTED');
  }

  if (Platform.isIOS) {
    debugPrint('🌐 IOS RUNTIME DETECTED');
    if (kDebugMode) {
      debugPrint('🌐 WIRELESS DEBUG DETECTED → iOS debug runtime');
    }
  }

  debugPrint(
    '🌐 PROFILE/RELEASE FIRESTORE STATUS → '
    '${kReleaseMode
        ? "release"
        : kProfileMode
        ? "profile"
        : "debug"}',
  );
}

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
  await MobileAds.instance.initialize();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FirestoreReadinessGate.instance.markFirstFrameReady();
  });

  final data = message.data;
  final user = FirebaseAuth.instance.currentUser;
  /*
  if (user != null && data['type'] == 'playdate_request') {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': message.notification?.title ?? 'BarkyMatches',
      'body': message.notification?.body ?? '',
      'recipientUserId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'payload': data,
    });
  }
  */
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
        'title': notification?.title ?? 'BarkyMatches',
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
    ) {
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

        appState.setSelectedAppointmentId(appointmentId);
        appState.setCurrentTab(NavTab.profile);
        appState.openProfileSubPage(ProfileSubPage.businessDashboard);

        return;
      }

      if (type.startsWith('groomy_appointment_')) {
        appState.handleNotificationTap(Map<String, dynamic>.from(data));
        return;
      }

      _handleRemoteMessage(message);
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

          // ───────────────── APPOINTMENT PAID TAP 🔥 ─────────────────
          if (type == 'appointment_paid' && payload['appointmentId'] != null) {
            final appointmentId = payload['appointmentId'].toString();

            debugPrint("💰 TAP → OPEN APPOINTMENT $appointmentId");

            final appState = context.read<AppState>();

            appState.setSelectedAppointmentId(appointmentId);

            appState.setCurrentTab(NavTab.profile);
            appState.openProfileSubPage(ProfileSubPage.businessDashboard);

            return;
          }

          if (type.startsWith('groomy_appointment_')) {
            appState.handleNotificationTap(Map<String, dynamic>.from(payload));
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
            appState.handleNotificationTap(Map<String, dynamic>.from(payload));
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
  final data = message.data;
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
  // ───────────────── APPOINTMENT PAID 🔥 ─────────────────
  if (type == 'appointment_paid' && data['appointmentId'] != null) {
    final appointmentId = data['appointmentId'].toString();

    debugPrint("💰 AUTO OPEN APPOINTMENT → $appointmentId");

    appState.ignoreNextNotificationTap();

    appState.setSelectedAppointmentId(appointmentId);

    appState.setCurrentTab(NavTab.profile);
    appState.openProfileSubPage(ProfileSubPage.businessDashboard);

    return;
  }

  if (type.startsWith('groomy_appointment_')) {
    appState.handleNotificationTap(Map<String, dynamic>.from(data));
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
    appState.handleNotificationTap(data);
    return;
  }
}

void main() async {
  if (kDebugMode) {
    debugPrint('Main - Starting main function...');
  }

  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  //await waitForInternet();
  await ensureFirebaseInitialized();
  FcmTokenService.attachRefreshListener();
  _authFcmSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) {
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
  logStartupEnvironmentDiagnostics();
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
  await Hive.initFlutter();

  Hive.registerAdapter(DogAdapter());

  final dogsBoxFuture = Hive.openBox<Dog>('dogsBox');
  final favoritesBoxFuture = Hive.openBox<Dog>('favoritesBox');
  final currentUserBoxFuture = Hive.openBox<String>('currentUserBox');
  final userBoxFuture = Hive.openBox<String>('userBox');
  final userDataBoxFuture = Hive.openBox<Map<dynamic, dynamic>>('userDataBox');

  dogsBox = await dogsBoxFuture;
  favoritesBox = await favoritesBoxFuture;
  currentUserBox = await currentUserBoxFuture;
  userBox = await userBoxFuture;
  userDataBox = await userDataBoxFuture;

  if (kDebugMode) {
    debugPrint('Main - Hive initialized, dogsBox size: ${dogsBox.length}');
  }

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

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('🔥 Initial message detected (terminated state)');
      await _handleRemoteMessage(initialMessage);
    }
  }

  // final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  //if (initialMessage != null) {
  //await _handleRemoteMessage(initialMessage);
  //}

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(initializeAsync());
  });

  if (false) {
    AuthTrap.signOut(reason: 'session_expired');
  } // 👈 فقط برای تست

  runApp(
    ChangeNotifierProvider(
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
        );

        IapService.instance.setSubscriptionActivatedCallback(() async {
          await appState.loadSubscriptionFromFirestore();

          debugPrint('🔄 UI refreshed');

          await Future.delayed(const Duration(milliseconds: 500));

          appState.openProfileSubPage(ProfileSubPage.businessRegister);
        });

        appState.markFirebaseInitialized();

        // ❗️ خیلی مهم: فقط این
        appState.startAuthListener();
        //AuthTrap.start();
        // AuthTrap.scheduleTokenDiagnostics();
        IapService.instance.setSubscriptionActivatedCallback(() async {
          await appState.loadSubscriptionFromFirestore();
          debugPrint('🔄 UI refreshed');
        });

        return appState;
      },
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

    WidgetsBinding.instance.addObserver(this);
  }

  void _handleDeepLinkOnce(Uri uri, String label) {
    if (_lastHandledLink == uri) return;
    _lastHandledLink = uri;
    debugPrint("$label: $uri");
    handleDeepLink(uri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed');

      final appState = context.read<AppState>();

      appState.ignoreNotificationIconTapFor(const Duration(milliseconds: 600));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppState>().locale;

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
        theme: AppTheme.theme(locale: locale),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          '/orderDetail': (context) => OrderDetailPage(
            sellerOrderId: ModalRoute.of(context)!.settings.arguments as String,
          ),
          '/appointmentPayment': (context) => AppointmentPaymentPage(
            appointmentId: ModalRoute.of(context)!.settings.arguments as String,
          ),
        },
        home: const AppEntry(),
      ),
    );
  }

  void handleDeepLink(Uri uri) async {
    if (kDebugMode) {
      debugPrint("🔗 DEEP LINK RECEIVED: ${uri.scheme}://${uri.host}");
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

      final appState = context.read<AppState>();

      /// 🧹 پاک کردن cart
      appState.clearCart();

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
