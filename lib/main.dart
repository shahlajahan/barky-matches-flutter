import 'dart:convert';
import 'dart:io' show InternetAddress, Platform, SocketException, File, Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_entry.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'debug/auth_trap.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';


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

bool _appCheckActivated = false;

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    if (kDebugMode) {
      print('Main - Initializing Firebase...');
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

AuthTrap.start();
    
  }

  // =========================
  // 🔐 Firebase App Check
  // =========================
  
  // =========================
  // 🔥 Firestore settings
  // =========================
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (kDebugMode) {
    print('🔥 Firebase AppId = ${DefaultFirebaseOptions.currentPlatform.appId}');
    print('🔥 Firebase ProjectId = ${DefaultFirebaseOptions.currentPlatform.projectId}');
    print('🔥 Firebase Bundle = ${DefaultFirebaseOptions.currentPlatform.iosBundleId}');
    print('Main - Firebase initialized successfully');
  }
}


Future<T> retry<T>(Future<T> Function() run) async {
  var delay = const Duration(milliseconds: 300);
  for (var i = 0; i < 5; i++) {
    try {
      return await run();
    } catch (e) {
      if (i == 4) {
        if (kDebugMode) {
          print('Main - Retry failed after 5 attempts: $e');
        }
        rethrow;
      }
      if (kDebugMode) {
        print('Main - Retry attempt ${i + 1} failed: $e');
      }
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
    debugPrint("🍏 iOS system notification will handle display (no local show)");
    return;
  }

  // 🔹 3️⃣ نمایش local notification (Android یا data-only)
  try {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // unique ID
      notification?.title ?? 'BarkyMatches',
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
    final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 3));
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
    final result = await InternetAddress.lookup('firebaseappcheck.googleapis.com').timeout(const Duration(seconds: 3));
    if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
      if (kDebugMode) {
        print('Main - Internet connection detected via firebaseappcheck.googleapis.com');
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

Future<void> setupFCM() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('Main - User granted permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('Main - Requesting permission again for notifications');
      }
      settings = await messaging.requestPermission();
    }

    // iOS Foreground notifications نمایش داده شوند
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    String? apnsToken;

    if (Platform.isIOS) {
      // optional ولی کمک می‌کند
      await messaging.setAutoInitEnabled(true);

      if (kDebugMode) {
  debugPrint('iOS: AutoInit enabled');
}


      // Retry تا APNs token آماده شود (در Release معمولاً چند ثانیه طول می‌کشه)
      for (int i = 0; i < 10; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await saveIosPushDebug(
        stage: 'after_apns_check',
        apnsToken: apnsToken,
      );

      if (apnsToken == null || apnsToken.isEmpty) {
        await saveIosPushDebug(
          stage: 'apns_missing',
          apnsToken: apnsToken,
          error: 'APNS_TOKEN_NULL',
        );
        return; // تا APNs نیاد، FCM رو ادامه نمی‌دیم
      }
    }

    // اینجا دیگه token رو shadow نمی‌کنیم
    token = await messaging.getToken();

    if (kDebugMode) {
  debugPrint('🔥 FCM Token = $token');
}

FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  token = newToken;
  if (kDebugMode) {
    debugPrint('♻️ FCM Token refreshed = $newToken');
  }
});


    await saveIosPushDebug(
      stage: 'after_fcm',
      apnsToken: apnsToken,
      fcmToken: token,
    );

    if (token != null) {
      if (kDebugMode) {
        print('Main - FCM Token: $token');

      }
      if (kDebugMode) {
  debugPrint('🍏 APNS Token = $apnsToken');
}


      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        try {
          final userDoc = await retry(() => userDocRef.get(GetOptions(source: Source.cache)).catchError((e) async {
            if (kDebugMode) {
              print('Main - Failed to get user document from cache: $e');
            }
            return await userDocRef.get(GetOptions(source: Source.server));
          }));

          if (userDoc.exists) {
            try {
              await retry(() => userDocRef.update({'fcmToken': token}));
              if (kDebugMode) {
                print('Main - Updated FCM token for user: ${user.uid}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Main - Failed to update FCM token: $e');
              }
            }
          } else {
            try {
              await retry(() => userDocRef.set({
                    'fcmToken': token,
                    'username': 'Anonymous',
                    'createdAt': FieldValue.serverTimestamp(),
                  }));
              if (kDebugMode) {
                print('Main - Created new user document with FCM token for user: ${user.uid}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Main - Failed to create user document: $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Main - Error accessing Firestore for FCM setup: $e');
          }
        }
      } else {
        if (kDebugMode) {
          print('Main - No user signed in, skipping FCM token update');
        }
      }
    } else {
      if (kDebugMode) {
        print('Main - Failed to get FCM token');
      }
    }

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

    FirebaseMessaging.onMessage.listen(_firebaseMessagingForegroundHandler);

FirebaseMessaging.onMessageOpenedApp.listen((message) {
  _handleRemoteMessage(message);
});


    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
  if (kDebugMode) {
    print('Main - Notification clicked: $response');
  }

  if (response.payload == null) return;

  try {
    final payload = jsonDecode(response.payload!);

    final type = (payload['type'] ?? '').toString();
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


    if ((type == 'like' || type == 'favorite') && payload['likerUserId'] != null) {
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
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      if (kDebugMode) {
        print('Main - Notification channel created: high_importance_channel');
      }
    }

    bool? exactAlarmPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    if (kDebugMode) {
      print('Main - Exact alarms permission granted: $exactAlarmPermissionGranted');
    }

    if (exactAlarmPermissionGranted != true) {
      if (kDebugMode) {
        print('Main - Warning: Exact alarms permission not granted. Notifications may not work as expected.');
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
  if (appState == null) return;

  if ((type == 'playdate_request' || type == 'playdate_response') &&
      data['requestId'] != null) {

    appState.ignoreNextNotificationTap(); // ✅ این خط اصلاح شد

    appState.setInitialPlaydateRequest(data['requestId'].toString());
    appState.setCurrentTab(NavTab.playdate);
  }
}

void main() async {
  if (kDebugMode) {
    print('Main - Starting main function...');
  }

  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  GoogleFonts.config.allowRuntimeFetching = true;

  await ensureFirebaseInitialized();

  

 if (kDebugMode) {
  await clearHive();
}


  try {
    await NotificationService().init();


  print("🔥 FCM TOKEN REALTIME = $token");

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


  await OffersManager.loadOffersOnce();

Future<void> initializeAsync() async {
  await setupFCM();
/*
  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    debugPrint('🔥 Initial message detected (terminated state)');
    await _handleRemoteMessage(initialMessage);
  }

  */
}


// final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
//if (initialMessage != null) {
  //await _handleRemoteMessage(initialMessage);
//}


//unawaited(initializeAsync());

if (false) {
  await AuthTrap.signOut(reason: 'PUT_REASON_HERE');
} // 👈 فقط برای تست

await IapService.instance.init();

  runApp(
  ChangeNotifierProvider(
    create: (context) {
      final appState = AppState(
        favoriteDogs: favoriteDogs,

        favoriteDogsNotifier: ValueNotifier<List<Dog>>(favoriteDogs),
        likesNotifier: ValueNotifier<Map<String, List<String>>>({}),
        onToggleFavorite: (Dog dog) async {
          await Provider.of<AppState>(context, listen: false)
              .toggleFavorite(dog);
        },
        notificationService: NotificationService(),
      );

      // ❗️ خیلی مهم: فقط این
      appState.startAuthListener();

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

class MyAppState extends State<MyApp>
    with WidgetsBindingObserver {

  //Locale _locale = const Locale('en');

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    debugPrint('🔄 App resumed → forcing Firestore reconnect');

    FirebaseFirestore.instance.enableNetwork();

    final appState = context.read<AppState>();

    // 👇 فقط از AppState استفاده کن
    appState.ignoreNotificationIconTapFor(
      const Duration(milliseconds: 600),
    );
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

    supportedLocales: const [
      Locale('en'),
      Locale('fa'),
      Locale('tr'),
    ],

    home: const AppEntry(),
  );
}
}
