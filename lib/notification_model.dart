import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String? id; // id رو optional می‌کنیم چون Firestore خودش document ID می‌سازه
  final String? title; // تغییر به اختیاری
  final String? body; // تغییر به اختیاری
  final DateTime timestamp;
  final String? payload;
  final bool isRead; // اضافه کردن فیلد isRead
  final String? type; // اضافه کردن نوع اعلان
  final String? lostDogId; // برای اعلان‌های lost_dog

  AppNotification({
    this.id,
    this.title, // اختیاری شد
    this.body, // اختیاری شد
    required this.timestamp,
    this.payload,
    required this.isRead, // اضافه کردن isRead به سازنده
    this.type, // اختیاری
    this.lostDogId, // اختیاری
  });

  // تبدیل به Map برای ذخیره تو Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'payload': payload,
      'isRead': isRead, // اضافه کردن isRead به Map
      'type': type,
      'lostDogId': lostDogId,
    };
  }

  // تبدیل از Map برای خوندن از Firestore
  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: map['title'] as String?, // اختیاری
      body: map['body'] as String?, // اختیاری
      timestamp: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      payload: map['payload'] as String?,
      isRead: map['isRead'] as bool? ?? false, // اضافه کردن isRead با مقدار پیش‌فرض
      type: map['type'] as String?, // اختیاری
      lostDogId: map['lostDogId'] as String?, // اختیاری
    );
  }
}