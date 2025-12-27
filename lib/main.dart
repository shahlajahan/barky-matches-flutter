import 'dart:convert';
import 'dart:io' show InternetAddress, Platform, SocketException, File, Directory;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show RootIsolateToken, BackgroundIsolateBinaryMessenger; // ایمپورت جدید
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
import 'dart:async';
import 'screens/lost_dog_report_page.dart';
import 'screens/lost_dogs_list_page.dart';
import 'screens/found_dog_report_page.dart';
import 'screens/found_dogs_list_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'playmate_page.dart';

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

Future<void> writeAppCheckToken() async {
  try {
    if (kDebugMode) {
      print('Main - Fetching App Check token...');
    }
    final tokenResult = await FirebaseAppCheck.instance.getToken(true);
    if (kDebugMode) {
      print('Main - App Check token: $tokenResult');
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/appcheck_detailed.txt');
    if (tokenResult != null) {
      await file.writeAsString(tokenResult);
      if (kDebugMode) {
        print('Main - App Check token written to: ${file.path}');
      }
    } else {
      await file.writeAsString('No token received');
      if (kDebugMode) {
        print('Main - No App Check token received');
      }
    }
    if (await file.exists()) {
      final content = await file.readAsString();
      if (kDebugMode) {
        print('Main - Content of appcheck_detailed.txt: $content');
      }
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Main - Error writing/reading App Check token file: $e');
      print('Main - StackTrace: $stackTrace');
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/appcheck_detailed.txt');
    await file.writeAsString('Error: $e\nStackTrace: $stackTrace');
    if (await file.exists()) {
      final content = await file.readAsString();
      if (kDebugMode) {
        print('Main - Content of appcheck_detailed.txt after error: $content');
      }
    }
  }
}

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    if (kDebugMode) {
      print('Main - Initializing Firebase...');
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (kDebugMode) {
        print('Main - Firebase initialized successfully');
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Main - Error initializing Firebase: $e');
      }
    }
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();
  if (kDebugMode) {
    print('Main - Handling a background message: ${message.messageId}');
    print('Main - Message data: ${message.data}');
    print('Main - Message notification: ${message.notification?.title} - ${message.notification?.body}');
  }
  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: [
            AndroidNotificationAction('open_app', 'Open App', showsUserInterface: true),
            AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true),
          ],
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

Future<void> _firebaseMessagingForegroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Main - Handling a foreground message: ${message.messageId}');
    print('Main - Message data: ${message.data}');
    print('Main - Message notification: ${message.notification?.title} - ${message.notification?.body}');
  }
  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

Future<void> _firebaseMessagingOpenedAppHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Main - App opened from notification: ${message.messageId}');
    print('Main - Message data: ${message.data}');
  }
  if (message.data['type'] == 'lost_dog' && message.data['lostDogId'] != null) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/lost_dogs_list', (route) => false);
  } else if (message.data['type'] == 'found_dog' && message.data['foundDogId'] != null) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/found_dogs_list', (route) => false);
  } else if (message.data['type'] == 'playDateRequest' && message.data['requestId'] != null) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/play_date_requests', (route) => false);
  } else if (message.data['type'] == 'like' && message.data['likerUserId'] != null) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/user_profile',
      (route) => false,
      arguments: {'userId': message.data['likerUserId']},
    );
  } else {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
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
    String? token;
    try {
      token = await messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Main - Failed to get FCM token: $e');
      }
    }
    if (token != null) {
      if (kDebugMode) {
        print('Main - FCM Token: $token');
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
    FirebaseMessaging.onMessageOpenedApp.listen(_firebaseMessagingOpenedAppHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (kDebugMode) {
          print('Main - Notification clicked: $response');
        }
        if (response.actionId == 'open_app' && response.payload != null) {
          try {
            final payload = jsonDecode(response.payload!);
            if (payload['type'] == 'playDateRequest' && payload['requestId'] != null) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/play_date_requests',
                (route) => false,
                arguments: {'requestId': payload['requestId']},
              );
            } else if (payload['type'] == 'like' || payload['type'] == 'favorite' && payload['likerUserId'] != null) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/user_profile',
                (route) => false,
                arguments: {'userId': payload['likerUserId']},
              );
            } else if (payload['type'] == 'lost_dog' && payload['lostDogId'] != null) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/lost_dogs_list', (route) => false);
            } else if (payload['type'] == 'found_dog' && payload['foundDogId'] != null) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/found_dogs_list', (route) => false);
            } else {
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Main - Error handling notification click: $e');
            }
          }
        }
      },
    );
    if (kDebugMode) {
      print('Main - flutter_local_notifications initialized: $initialized');
    }
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    if (kDebugMode) {
      print('Main - Notification channel created: high_importance_channel');
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

Future<List<Dog>> _fetchDogsFromFirestoreOnMain() async {
  if (kDebugMode) {
    print('Main - Starting _fetchDogsFromFirestoreOnMain');
  }
  try {
    await ensureFirebaseInitialized();
    var dogsSnapshot = await retry(() => FirebaseFirestore.instance.collection('dogs').get(GetOptions(source: Source.cache)).catchError((e) async {
      if (kDebugMode) {
        print('Main - Failed to get dogs from cache: $e');
      }
      return await FirebaseFirestore.instance.collection('dogs').get(GetOptions(source: Source.server));
    }));
    if (dogsSnapshot.docs.isEmpty) {
      if (kDebugMode) {
        print('Main - No dogs found in cache, trying server');
      }
      dogsSnapshot = await retry(() => FirebaseFirestore.instance.collection('dogs').get(GetOptions(source: Source.server)));
    }
    if (kDebugMode) {
      print('Main - Fetched ${dogsSnapshot.docs.length} dogs from Firestore');
    }
    final uniqueDogs = <String, Dog>{};
    for (var doc in dogsSnapshot.docs) {
      final data = doc.data();
      final dog = Dog(
        id: doc.id,
        name: data['name'] != null ? data['name'].trim() : '',
        breed: data['breed'] as String? ?? '',
        age: data['age'] != null ? (data['age'] is num ? data['age'].toInt() : int.parse(data['age'].toString())) : 0,
        gender: data['gender'] as String? ?? '',
        healthStatus: data['healthStatus'] as String? ?? '',
        isNeutered: data['isNeutered'] as bool? ?? false,
        description: data['description'] as String?,
        traits: List<String>.from(data['traits'] ?? []),
        ownerGender: data['ownerGender'] as String?,
        imagePaths: List<String>.from(data['imagePaths'] ?? []),
        isAvailableForAdoption: data['isAvailableForAdoption'] as bool? ?? false,
        isOwner: data['isOwner'] as bool? ?? false,
        ownerId: data['ownerId'] as String?,
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      );
      if (!uniqueDogs.containsKey(dog.id)) {
        uniqueDogs[dog.id] = dog;
        if (kDebugMode) {
          print('Main - Loaded dog: ${dog.name}, id: ${doc.id}, ownerId: ${dog.ownerId}');
        }
      } else {
        if (kDebugMode) {
          print('Main - Skipped duplicate dog: ${dog.name}, id: ${doc.id}, ownerId: ${dog.ownerId}');
        }
        await FirebaseFirestore.instance.collection('dogs').doc(doc.id).delete();
        if (kDebugMode) {
          print('Main - Deleted duplicate dog from Firestore: ${doc.id}');
        }
      }
    }
    if (kDebugMode) {
      print('Main - _fetchDogsFromFirestoreOnMain completed with ${uniqueDogs.length} dogs');
    }
    return uniqueDogs.values.toList();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Main - Error in _fetchDogsFromFirestoreOnMain: $e');
      print('Main - StackTrace: $stackTrace');
    }
    // داده نمونه آفلاین
    final fallbackDog = Dog(
      id: 'fallback_dog_${DateTime.now().millisecondsSinceEpoch}',
      name: 'FallbackDog',
      ownerId: '14OghGfziQhObe96le2FpKG9HtG2',
      breed: 'breedGoldenRetriever',
      age: 3,
      gender: 'male',
      healthStatus: 'healthy',
      isNeutered: true,
      description: 'A fallback dog for offline mode',
      traits: ['friendly', 'playful'],
      imagePaths: ['https://example.com/dog.jpg'],
      latitude: 41.0103,
      longitude: 28.6724,
      isAvailableForAdoption: false,
      isOwner: false,
    );
    // ذخیره داده نمونه در Hive
    if (dogsBox.isOpen) {
      await dogsBox.put(fallbackDog.id, fallbackDog);
      if (kDebugMode) {
        print('Main - Added fallback dog to dogsBox: ${fallbackDog.name}, id: ${fallbackDog.id}');
      }
    }
    return [fallbackDog];
  }
}

Future<List<Dog>> processDogsPureDart(List<Dog> dogs) async {
  return dogs;
}

Future<void> cleanDuplicateDogs() async {
  if (kDebugMode) {
    print('Main - Starting cleanDuplicateDogs');
  }
  try {
    await ensureFirebaseInitialized();
    final dogsSnapshot = await retry(() => FirebaseFirestore.instance.collection('dogs').get());
    final seenNames = <String, Set<String>>{};
    for (var doc in dogsSnapshot.docs) {
      final data = doc.data();
      final id = doc.id;
      final name = data['name'] != null ? data['name'].trim() : '';
      final ownerId = data['ownerId'] as String? ?? '';
      final key = '$name|$ownerId';
      if (seenNames.containsKey(name) && seenNames[name]!.contains(ownerId)) {
        await FirebaseFirestore.instance.collection('dogs').doc(id).delete();
        if (kDebugMode) {
          print('Main - Deleted duplicate dog: $id (name: $name, ownerId: $ownerId)');
        }
      } else {
        seenNames.putIfAbsent(name, () => <String>{}).add(ownerId);
      }
    }
    if (kDebugMode) {
      print('Main - cleanDuplicateDogs completed');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Main - Error in cleanDuplicateDogs: $e');
      print('Main - StackTrace: $stackTrace');
    }
  }
}

Future<List<Dog>> _fetchAndStoreDogsInHive() async {
  if (kDebugMode) {
    print('Main - Starting _fetchAndStoreDogsInHive');
  }
  await cleanDuplicateDogs();
  final dogs = await _fetchDogsFromFirestoreOnMain();
  final processedDogs = await compute(processDogsPureDart, dogs);

  if (!dogsBox.isOpen) {
    await Hive.initFlutter();
    Hive.registerAdapter(DogAdapter());
    dogsBox = await Hive.openBox<Dog>('dogsBox');
    if (kDebugMode) {
      print('Main - Initialized and opened dogsBox in _fetchAndStoreDogsInHive');
    }
  }
  if (dogsBox.isOpen) {
    final uniqueDogs = <String, Dog>{};
    for (var dog in processedDogs) {
      uniqueDogs[dog.id] = dog;
    }

    final existingKeys = dogsBox.keys.cast<String>().toList();
    for (var key in existingKeys) {
      if (!uniqueDogs.containsKey(key)) {
        await dogsBox.delete(key);
        if (kDebugMode) {
          print('Main - Deleted stale dog from Hive: $key');
        }
      }
    }

    for (final entry in uniqueDogs.entries) {
      await dogsBox.put(entry.key, entry.value);
      if (kDebugMode) {
        print('Main - Added/Updated dog to dogsBox: ${entry.value.name}, id=${entry.value.id}, ownerId=${entry.value.ownerId}');
      }
    }

    if (kDebugMode) {
      print('Main - Total dogs added to dogsBox: ${dogsBox.length}');
    }
  } else {
    if (kDebugMode) {
      print('Main - Error: dogsBox is not open');
    }
  }
  return processedDogs;
}

Future<void> signIn() async {
  try {
    if (kDebugMode) {
      print('Main - Checking internet before sign-in...');
    }
    bool isConnected = await checkInternetConnection();
    if (!isConnected) {
      if (kDebugMode) {
        print('Main - No internet connection, skipping sign-in');
      }
      return;
    }
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'vallirocenter@gmail.com',
      password: 'Pass1234',
    );
    if (kDebugMode) {
      print('Main - Signed in as: ${FirebaseAuth.instance.currentUser?.uid}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Main - Error signing in: $e');
    }
  }
}

void main() async {
  if (kDebugMode) {
    print('Main - Starting main function...');
  }
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  // تعریف firestoreDogs در سطح main
  List<Dog> firestoreDogs = [
    Dog(
      id: 'default_dog_${DateTime.now().millisecondsSinceEpoch}',
      name: 'DefaultDog',
      ownerId: '14OghGfziQhObe96le2FpKG9HtG2',
      breed: 'breedGoldenRetriever',
      age: 3,
      gender: 'male',
      healthStatus: 'healthy',
      isNeutered: true,
      description: 'A default dog for initial load',
      traits: ['friendly', 'playful'],
      imagePaths: ['https://example.com/dog.jpg'],
      latitude: 41.0103,
      longitude: 28.6724,
      isAvailableForAdoption: false,
      isOwner: false,
    ),
  ];

  await clearHive();

  await ensureFirebaseInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(DogAdapter());
  dogsBox = await Hive.openBox<Dog>('dogsBox');
  favoritesBox = await Hive.openBox<Dog>('favoritesBox');
  currentUserBox = await Hive.openBox<String>('currentUserBox');
  userBox = await Hive.openBox<String>('userBox');
  userDataBox = await Hive.openBox<Map<dynamic, dynamic>>('userDataBox');
  if (kDebugMode) {
    print('Main - Hive initialized, dogsBox opened with size: ${dogsBox.length}');
  }

  // ذخیره داده نمونه در Hive
  await dogsBox.put(firestoreDogs[0].id, firestoreDogs[0]);
  if (kDebugMode) {
    print('Main - Added default dog to dogsBox: ${firestoreDogs[0].name}, id: ${firestoreDogs[0].id}');
  }

  // اجرای عملیات‌های async در پس‌زمینه
  Future<void> initializeAsync() async {
    try {
      // فعال کردن App Check
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        );
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        if (kDebugMode) {
          print('Main - Firebase App Check activated with Debug Provider');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('Main - Error activating App Check: $e');
          print('Main - StackTrace: $stackTrace');
        }
      }

      await writeAppCheckToken();

      try {
        await retry(() => FirebaseFirestore.instance.collection('ping').limit(1).get());
        if (kDebugMode) {
          print('Main - App Check ping successful');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('Main - Error in App Check ping: $e');
          print('Main - StackTrace: $stackTrace');
        }
      }

      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
        if (kDebugMode) {
          print('Main - Firebase Analytics initialized.');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Main - Error initializing Firebase Analytics: $e');
        }
      }

      try {
        await NotificationService().init();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        await setupFCM();
        if (kDebugMode) {
          print('Main - FCM setup completed.');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Main - Error in FCM setup: $e');
        }
      }

      // انتقال عملیات سنگین به isolate
      try {
        final fetchedDogs = await compute<dynamic, List<Dog>>((_) async {
          if (RootIsolateToken.instance != null) {
            BackgroundIsolateBinaryMessenger.ensureInitialized(RootIsolateToken.instance!);
            await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
            if (kDebugMode) {
              print('Main - Firebase initialized in isolate');
            }
          } else {
            if (kDebugMode) {
              print('Main - RootIsolateToken is null in isolate');
            }
            return [];
          }
          await signIn();
          return await _fetchAndStoreDogsInHive();
        }, null);
        if (fetchedDogs.isNotEmpty) {
          firestoreDogs = fetchedDogs;
          if (kDebugMode) {
            print('Main - Fetched ${fetchedDogs.length} dogs in isolate');
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('Main - Error in isolate: $e');
          print('Main - StackTrace: $stackTrace');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Main - Error in initializeAsync: $e');
        print('Main - StackTrace: $stackTrace');
      }
    }
  }

  if (kDebugMode) {
    print('Main - Starting initializeAsync...');
  }
  unawaited(initializeAsync());

  if (kDebugMode) {
    print('Main - Preparing to run app...');
    print('Main - DogsBox length before WelcomePage: ${dogsBox.length}');
  }

  final favoriteDogs = favoritesBox.isOpen ? favoritesBox.values.cast<Dog>().toList() : <Dog>[];
  if (kDebugMode) {
    print('Main - Initial favorite dogs count: ${favoriteDogs.length}');
    print('Main - Building app with ${firestoreDogs.length} dogs in dogsList');
  }

  String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  const String currentUserName = 'TestUser';

  if (currentUserId == null) {
    currentUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
  }

  if (kDebugMode) {
    print('Main - Running app with currentUserId: $currentUserId');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(
        dogsList: firestoreDogs,
        favoriteDogs: favoriteDogs,
        currentUserName: currentUserName,
        currentUserId: currentUserId,
        favoriteDogsNotifier: ValueNotifier<List<Dog>>(favoriteDogs),
        likesNotifier: ValueNotifier<Map<String, List<String>>>({}),
        onToggleFavorite: (Dog dog) async {
          await Provider.of<AppState>(context, listen: false).toggleFavorite(dog);
        },
        notificationService: NotificationService(),
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<State<MyApp>>();
    state?.setState(() {
      (state as MyAppState)._locale = newLocale;
    });
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('Main - Building MyApp...');
      print('Main - Current theme textTheme: ${ThemeData().textTheme}');
    }
    final localization = AppLocalizations.of(context);
    AndroidNotificationChannel localizedChannel = channel;
    if (localization != null) {
      localizedChannel = AndroidNotificationChannel(
        'high_importance_channel',
        localization.notificationChannelName,
        importance: Importance.max,
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BarkyMatches',
      locale: _locale,
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
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: _locale.languageCode == 'fa' ? const TextTheme() : GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.pink,
        fontFamily: _locale.languageCode == 'fa' ? 'Vazirmatn' : 'Poppins',
      ),
      home: Directionality(
        textDirection: _locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        child: const SplashScreen(),
      ),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/home': (context) => Builder(
          builder: (context) => HomePage(
            dogsList: Provider.of<AppState>(context, listen: false).dogsList,
            favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
            onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
          ),
        ),
        '/adoption': (context) => Builder(
          builder: (context) => AdoptionPage(
            dogs: Provider.of<AppState>(context, listen: false).dogsList,
            favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
            onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
          ),
        ),
        '/favorites': (context) => Builder(
          builder: (context) => FavoritesPage(
            favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
            dogsList: Provider.of<AppState>(context, listen: false).dogsList,
            onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
          ),
        ),
        '/play_date_requests': (context) => Builder(
          builder: (context) => PlayDateRequestsPageNew(
            dogsList: Provider.of<AppState>(context, listen: false).dogsList,
            favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
            onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
            initialRequestId: null,
          ),
        ),
        '/notifications': (context) => Builder(
          builder: (context) => NotificationsPage(
            currentUserId: Provider.of<AppState>(context, listen: false).currentUserId ?? 'default_user_id',
          ),
        ),
        '/schedule_playdate': (context) => Builder(
          builder: (context) => PlayDateSchedulingPage(
            dogsList: Provider.of<AppState>(context, listen: false).dogsList,
            favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
            onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
          ),
        ),
        '/lost_dog_report': (context) => const LostDogReportPage(),
        '/lost_dogs_list': (context) => const LostDogsListPage(),
        '/found_dog_report': (context) => const FoundDogReportPage(),
        '/found_dogs_list': (context) => const LostDogsListPage(),
        '/playmate': (context) => PlaymatePage(
          dogs: Provider.of<AppState>(context, listen: false).dogsList,
          currentUserId: Provider.of<AppState>(context, listen: false).currentUserId ?? 'default_user_id',
          favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
          onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
        ),
      },
    );
  }
}