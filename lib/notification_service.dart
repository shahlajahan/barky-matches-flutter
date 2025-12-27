import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'user_profile_page.dart';
import 'dog.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_state.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (!Firebase.apps.contains(Firebase.app())) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await Future.delayed(const Duration(milliseconds: 1000));
      print('NotificationService - Firebase initialized');
    } else {
      print('NotificationService - Firebase already initialized');
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tehran'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('NotificationService - Notification clicked with payload: ${response.payload}');
        if (response.payload != null) {
          try {
            final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
            if (payload['type'] == 'like' && payload['likerUserId'] != null) {
              final likerUserId = payload['likerUserId'] as String;
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) {
                    final appState = AppState.of(context);
                    return UserProfilePage(
                      dogsList: Hive.box<Dog>('dogsBox').values.toList(),
                      favoriteDogs: appState.favoriteDogs,
                      onToggleFavorite: appState.onToggleFavorite,
                      userId: likerUserId,
                    );
                  },
                ),
              );
            } else if (payload['type'] == 'playDateRequest' && payload['requestId'] != null) {
              navigatorKey.currentState?.pushNamed('/play_date_requests');
            } else if (payload['type'] == 'lost_dog' && payload['lostDogId'] != null) {
              navigatorKey.currentState?.pushNamed('/lost_dogs_list');
            } else {
              navigatorKey.currentState?.pushNamed('/home');
            }
          } catch (e) {
            print('NotificationService - Error parsing notification payload: $e');
          }
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await scheduleTestNotification();
    print('NotificationService initialized');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? likerUserId,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      print('NotificationService - Notification shown: id=$id, title=$title, body=$body');
    } catch (e) {
      print('NotificationService - Error showing notification: $e');
    }
  }

  Future<void> scheduleReminderNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    print('NotificationService - Scheduling reminder for $id at $scheduledTime');
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('NotificationService - Reminder scheduled for $id');
    } catch (e) {
      print('NotificationService - Failed to schedule notification: $e');
      throw Exception('Failed to schedule notification. Please ensure exact alarm permissions are granted.');
    }
  }

  Future<void> sendInstantNotificationToUser(
    String recipientUserId,
    String title,
    String body,
  ) async {
    try {
      if (!Firebase.apps.contains(Firebase.app())) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await Future.delayed(const Duration(milliseconds: 1000));
        print('NotificationService - Firebase initialized for sendInstantNotification');
      }

      final db = FirebaseFirestore.instance;
      await db.collection('notifications').add({
        'recipientUserId': recipientUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'title': title,
        'body': body,
        'payload': jsonEncode({
          'type': 'instant_notification',
        }),
        'isRead': false,
      });
      print('NotificationService - Sent instant notification to user $recipientUserId: $title - $body');
    } catch (e) {
      print('NotificationService - Failed to send instant notification to user $recipientUserId: $e');
      throw Exception('Failed to send instant notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> scheduleTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        'test_notification'.hashCode,
        'Test Reminder',
        'This is a test notification!',
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('NotificationService - Scheduled test notification for 5 minutes from now');
    } catch (e) {
      print('NotificationService - Failed to schedule test notification: $e');
    }
  }
}