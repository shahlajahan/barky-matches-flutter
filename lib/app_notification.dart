import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String? id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? payload;
  final bool isRead;

  AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.payload,
    required this.isRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'payload': payload,
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: map['title'] as String,
      body: map['body'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      payload: map['payload'] as String?,
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}