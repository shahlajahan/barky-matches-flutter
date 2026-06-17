import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String? id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? payload; // همیشه String یا null
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
    'createdAt': Timestamp.fromDate(timestamp),
    'payload': payload,
    'isRead': isRead,
  };
}

  factory AppNotification.fromMap(
  String id,
  Map<String, dynamic> map,
) {
  String? payloadString;
  final rawPayload = map['payload'];

  if (rawPayload is String) {
    payloadString = rawPayload;
  } else if (rawPayload is Map<String, dynamic>) {
    payloadString = jsonEncode(rawPayload);
  }

  final ts =
      map['createdAt'] ??
      map['timestamp'];

  return AppNotification(
    id: id,
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    timestamp:
        ts is Timestamp
            ? ts.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0),
    payload: payloadString,
    isRead: map['isRead'] as bool? ?? false,
  );
}
}
