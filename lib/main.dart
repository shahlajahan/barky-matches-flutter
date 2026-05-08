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
import 'app_entry.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'dog.dart';
import 'welcome_page.dart';
import 'home_page.dart';
import 'adoption_page.dart';
import 'favorites_page.dart';
import 'play_date_requests_page_new.dart';
import 'notifications_page.dart';
import 'splash_screen.dart';
import 'app_state.dart';
import 'notification_service.dart';
import 'play_date_scheduling_page.dart';
import 'screens/lost_dog_report_page.dart';
import 'screens/lost_dogs_list_page.dart';
import 'screens/found_dog_report_page.dart';
import 'screens/found_dogs_list_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'playmate_page.dart';
import 'offers_manager.dart';
import 'dart:async';
import 'ui/shell/barky_scaffold.dart';
import 'ui/shell/nav_tab.dart';
import 'home_gate.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'nav_logger.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:app_links/app_links.dart';
import 'ui/orders/order_detail_page.dart';

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
        print('Main - Cleared Hive directory: ${hiveDir.path}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - Error clearing Hive directory: $e');
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
        .doc('ios_${stage}')
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

    if (result != ConnectivityResult.none) {
      debugPrint('🌐 Internet is AVAILABLE');
      return;
    }

    debugPrint('⏳ Waiting for internet... (${i + 1})');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  throw Exception('No internet connection detected');
}

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  print("🔥 Firebase initialized");

  await Future.delayed(const Duration(seconds: 1));

  debugPrint('🔥 Firebase ready');
}

Future<void> ensureFirestoreReady() async {
  int retries = 0;

  while (retries < 5) {
    try {
      await FirebaseFirestore.instance.enableNetwork();

      debugPrint("🔥 Firestore NETWORK ENABLED");

      return;
    } catch (e) {
      debugPrint("⏳ Firestore retry ${retries + 1} → $e");

      await Future.delayed(Duration(seconds: retries + 1));

      retries++;
    }
  }

  debugPrint("❌ Firestore FAILED");
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
        ),
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(data),
    );

    debugPrint("🔔 Local notification displayed");
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
        print('Main - Internet connection detected via dns.google');
      }
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - Error checking internet connection: $e');
    }
  }

  try {
    final result = await InternetAddress.lookup(
      'firebaseappcheck.googleapis.com',
    ).timeout(const Duration(seconds: 3));
    if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
      if (kDebugMode) {
        print(
          'Main - Internet connection detected via firebaseappcheck.googleapis.com',
        );
      }
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - Error checking firebaseappcheck.googleapis.com: $e');
    }
  }

  if (kDebugMode) {
    print('Main - No internet connection detected');
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
  final context = navigatorKey.currentContext;
  final appState = context?.read<AppState>();

  if (appState == null ||
      appState.isGuestUser ||
      !appState.isUserProfileReady ||
      appState.currentUserId == null) {
    debugPrint('🚫 Auth not ready/guest → skip FCM setup');
    return;
  }

  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    final settings = await messaging.getNotificationSettings();

    if (kDebugMode) {
      print(
        'Main - Notification permission status: ${settings.authorizationStatus}',
      );
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      debugPrint(
        '🚫 setupFCM skipped: notification permission not granted yet',
      );
      return;
    }

    // iOS Foreground
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    String? apnsToken;

    if (Platform.isIOS) {
      await messaging.setAutoInitEnabled(true);

      if (kDebugMode) {
        debugPrint('iOS: AutoInit enabled');
      }

      for (int i = 0; i < 10; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (apnsToken == null || apnsToken.isEmpty) {
        debugPrint("⚠️ APNS not ready");
      }
    }

    // 🔥 FCM TOKEN
    token = await messaging.getToken();

    if (kDebugMode) {
      debugPrint("🔥 FCM token fetched: ${token != null}");
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      token = newToken;
      if (kDebugMode) {
        debugPrint('♻️ FCM token refreshed');
      }
    });

    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        final userDoc = await retry(() => userDocRef.get());

        // ==========================
        // 👤 USER TOKEN
        // ==========================
        if (userDoc.exists) {
          await retry(() => userDocRef.update({'fcmToken': token}));

          // ==========================
          // ☁️ SYNC BUSINESS TOKEN (Cloud Function)
          // ==========================
          try {
            await FirebaseFunctions.instance
                .httpsCallable('syncBusinessToken')
                .call({'token': token});

            debugPrint("☁️ Business token synced via Cloud Function");
          } catch (e) {
            debugPrint("❌ syncBusinessToken failed: $e");
          }

          debugPrint("✅ User token updated: ${user.uid}");
        } else {
          await retry(
            () => userDocRef.set({
              'fcmToken': token,
              'createdAt': FieldValue.serverTimestamp(),
            }),
          );

          debugPrint("✅ User created with token");
        }
      } else {
        debugPrint('❌ No user logged in');
      }
    } else {
      debugPrint('❌ Failed to get FCM token');
    }
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

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
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
          print('Main - Notification clicked: $response');
        }

        if (response.payload == null) return;

        try {
          final payload = jsonDecode(response.payload!);

          final type = (payload['type'] ?? '').toString();

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
            print('Main - Error handling notification click: $e');
          }
        }
      },
    );

    if (kDebugMode) {
      print('Main - flutter_local_notifications initialized: $initialized');
    }

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      if (kDebugMode) {
        print('Main - Notification channel created: high_importance_channel');
      }
    }

    bool? exactAlarmPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();

    if (kDebugMode) {
      print(
        'Main - Exact alarms permission granted: $exactAlarmPermissionGranted',
      );
    }

    if (exactAlarmPermissionGranted != true) {
      if (kDebugMode) {
        print(
          'Main - Warning: Exact alarms permission not granted. Notifications may not work as expected.',
        );
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - Error in setupFCM: $e');
    }
  }
}

String? token; // متغیر اصلی که باید آپدیت بشه

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
}

void main() async {
  if (kDebugMode) {
    print('Main - Starting main function...');
  }

  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  GoogleFonts.config.allowRuntimeFetching = true;
  await waitForInternet();
  await ensureFirebaseInitialized();
  //await FirebaseAuth.instance.signOut();
  //await AuthTrap.signOut(reason: 'manual_logout');

  // 👇 این خط جدید (اینجااااا)
  //await FirebaseAuth.instance.authStateChanges().first;

  // 🔥 wait until Firestore actually ready (real gate)

  await testHttps();

  // 🔥 INTERNET TEST
  final hasInternet = await checkInternetConnection();
  print("🌐 INTERNET STATUS = $hasInternet");
  if (kDebugMode) {
    await clearHive();
  }

  try {
    await NotificationService().init();

    if (kDebugMode) {
      print("🔥 FCM token initialized: ${token != null}");
    }

    if (kDebugMode) {
      print('Main - NotificationService initialized (MAIN)');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - NotificationService init failed in main: $e');
    }
  }
  await Hive.initFlutter();

  Hive.registerAdapter(DogAdapter());

  // 🔥 TEMP FIX (Hive migration issue)
  await Hive.deleteBoxFromDisk('dogsBox');

  dogsBox = await Hive.openBox<Dog>('dogsBox');
  favoritesBox = await Hive.openBox<Dog>('favoritesBox');
  currentUserBox = await Hive.openBox<String>('currentUserBox');
  userBox = await Hive.openBox<String>('userBox');
  userDataBox = await Hive.openBox<Map<dynamic, dynamic>>('userDataBox');

  if (kDebugMode) {
    print('Main - Hive initialized, dogsBox size: ${dogsBox.length}');
  }

  List<Dog> firestoreDogs = [];
  final favoriteDogs = favoritesBox.isOpen
      ? favoritesBox.values.cast<Dog>().toList()
      : <Dog>[];

  if (kDebugMode) {
    print('Main - Initial favorite dogs count: ${favoriteDogs.length}');
    print('Main - firestoreDogs count: ${firestoreDogs.length}');
  }

  Future<void> initializeAsync() async {
    final context = navigatorKey.currentContext;
    var authGateOpen = context == null;

    if (context != null) {
      for (int i = 0; i < 80; i++) {
        final appState = context.read<AppState>();
        final uid = appState.currentUserId;

        if (appState.isUserProfileReady &&
            (appState.isGuestUser || (uid != null && uid.isNotEmpty))) {
          debugPrint('✅ Startup auth gate open → uid=$uid');
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

    await OffersManager.loadOffersOnce();
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

  //unawaited(initializeAsync());

  if (false) {
    AuthTrap.signOut(reason: 'session_expired');
  } // 👈 فقط برای تست

  await IapService.instance.init();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    initializeAsync();
  });
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

        // ❗️ خیلی مهم: فقط این
        appState.startAuthListener();
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

    return MaterialApp(
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
      supportedLocales: const [Locale('en'), Locale('fa'), Locale('tr')],
      routes: {
        '/orderDetail': (context) => OrderDetailPage(
          sellerOrderId: ModalRoute.of(context)!.settings.arguments as String,
        ),
      },
      home: const AppEntry(),
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
      debugPrint("🔥 VERIFY ORDER ID FROM DEEPLINK: ${orderId != null && orderId.isNotEmpty}");
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

      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint("❌ CONTEXT NULL");
        return;
      }

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
