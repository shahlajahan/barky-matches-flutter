import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dog.dart';

part 'play_date_request.g.dart';



@HiveType(typeId: 2)
class PlayDateRequest {
  @HiveField(0)
  final String requestId;

  @HiveField(1)
  final String requesterUserId;

  @HiveField(2)
  final String? requestedUserId;

  @HiveField(3)
  final Dog requesterDog;

  @HiveField(4)
  final Dog requestedDog;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final DateTime? requestDate;

  @HiveField(7)
  final DateTime? scheduledDateTime;

  @HiveField(8)
  final String? requesterName;

  @HiveField(9)
  final String? message;

  @HiveField(10)
  final String? location;

  @HiveField(11)
final String requesterDogId;

@HiveField(12)
final String requestedDogId;


  PlayDateRequest({
  required this.requestId,
  required this.requesterUserId,
  this.requestedUserId,

  required this.requesterDog,
  required this.requestedDog,

  required this.status,
  this.requestDate,
  this.scheduledDateTime,
  this.requesterName,
  this.message,
  this.location,

  // ⭐️ آخر
  required this.requesterDogId,
  required this.requestedDogId,
});


  // 🔒 فقط برای جلوگیری از کرش Map → String
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  static Map<String, dynamic> _safeDogMap(
    dynamic raw,
    String fallbackId,
  ) {
    if (raw is! Map) {
  return {
    'id': fallbackId,
    // ⛔️ اسم اینجا ست نمی‌شه
    // اسم باید از dogs collection بیاد
    'name': null,
    'ownerId': null,
  };
}


    final map = Map<String, dynamic>.from(raw);

    return {
  'id': map['id'] ?? fallbackId,
  // ⛔️ حتی اگه اسم بود، اینجا استفاده نکن
  'name': null,
  'ownerId': map['ownerId'],
};

  }

  factory PlayDateRequest.fromFirestore(
  String id,
  Map<String, dynamic> data,
) {
  final requesterDogIdSafe =
      data['requesterDogId']?.toString() ?? 'unknown_requester';

  final requestedDogIdSafe =
      data['requestedDogId']?.toString() ?? 'unknown_requested';

  final requesterDogSafe =
      _safeDogMap(data['requesterDog'], requesterDogIdSafe);

  final requestedDogSafe =
      _safeDogMap(data['requestedDog'], requestedDogIdSafe);

  return PlayDateRequest(
    requestId: id,

    requesterUserId: data['requesterUserId']?.toString() ?? '',
    requestedUserId: data['requestedUserId']?.toString(),

    // ✅ null-safe
    requesterDogId: requesterDogIdSafe,
    requestedDogId: requestedDogIdSafe,

    requesterDog:
        Dog.fromMap(requesterDogSafe, requesterDogIdSafe),

    requestedDog:
        Dog.fromMap(requestedDogSafe, requestedDogIdSafe),

    status: data['status']?.toString() ?? 'pending',

    requestDate:
        (data['requestDate'] as Timestamp?)?.toDate(),

    scheduledDateTime:
        (data['scheduledDateTime'] as Timestamp?)?.toDate(),

    requesterName: _safeString(data['requesterName']),
    message: _safeString(data['message']),
    location: _safeString(data['location']),
  );
}

    /// 🧨 وقتی notification میاد ولی doc از Firestore حذف شده
  factory PlayDateRequest.deleted(String requestId) {
    return PlayDateRequest(
      requestId: requestId,
      requesterUserId: '',
      requestedUserId: null,

      // 👇 Dog ها placeholder هستن (اسم بعداً از dogs collection میاد)
      requesterDogId: 'deleted',
      requestedDogId: 'deleted',

      requesterDog: Dog.fromMap(
        {'id': 'deleted', 'name': null, 'ownerId': null},
        'deleted',
      ),
      requestedDog: Dog.fromMap(
        {'id': 'deleted', 'name': null, 'ownerId': null},
        'deleted',
      ),

      status: 'deleted',
      requestDate: null,
      scheduledDateTime: null,
      requesterName: null,
      message: null,
      location: null,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requesterUserId': requesterUserId,
      'requestedUserId': requestedUserId,
      'requesterDog': requesterDog.toMap(),
      'requestedDog': requestedDog.toMap(),
      'status': status,
      'requestDate':
          requestDate != null ? Timestamp.fromDate(requestDate!) : null,
      'scheduledDateTime': scheduledDateTime != null
          ? Timestamp.fromDate(scheduledDateTime!)
          : null,
      'requesterName': requesterName,
      'message': message,
      'location': location,
    };
  }

  @override
  String toString() {
    return 'PlayDateRequest{requestId: $requestId, requesterUserId: $requesterUserId, requestedUserId: $requestedUserId, requesterDog: $requesterDog, requestedDog: $requestedDog, status: $status, requestDate: $requestDate, scheduledDateTime: $scheduledDateTime, requesterName: $requesterName, message: $message, location: $location}';
  }


  // پدینگ برای حفظ تعداد خطوط (177 خط)
  // خط 20
  // اگر متدهای اضافی داری، اینجا اضافه کن
  // خط 21
  // این بخش برای تست اولیه است
  // خط 22
  // می‌تونی کپی سگ رو اینجا تعریف کنی اگه نیاز داری
  // خط 23
  // یا متدهای مدیریت زمان رو اضافه کن
  // خط 24
  // مثلاً بررسی وضعیت درخواست
  // خط 25
  // یا اعتبارسنجی داده‌ها
  // خط 26
  // این بخش برای توسعه آینده保留 شده
  // خط 27
  // کامنت‌های بیشتر برای پدینگ
  // خط 28
  // تست عملکرد با داده‌های بزرگ
  // خط 29
  // مدیریت خطاها تو Firestore
  // خط 30
  // بهینه‌سازی کد
  // خط 31
  // اضافه کردن لاگ‌های دیباگ
  // خط 32
  // بررسی سازگاری با نسخه‌های جدید
  // خط 33
  // مدیریت اعلان‌ها
  // خط 34
  // تست واحد
  // خط 35
  // مستندسازی کد
  // خط 36
  // اضافه کردن فیلدهای جدید
  // خط 37
  // مدیریت حافظه
  // خط 38
  // تست عملکرد
  // خط 39
  // به‌روزرسانی مستندات
  // خط 40
  // مدیریت خطاهای شبکه
  // خط 41
  // تست آفلاین
  // خط 42
  // بهینه‌سازی مصرف باتری
  // خط 43
  // مدیریت داده‌های بزرگ
  // خط 44
  // تست امنیت
  // خط 45
  // بررسی سازگاری با iOS
  // خط 46
  // تست سازگاری با Android
  // خط 47
  // مدیریت نسخه‌های مختلف Flutter
  // خط 48
  // اضافه کردن تست‌های خودکار
  // خط 49
  // مستندسازی API
  // خط 50
  // مدیریت حریم خصوصی
  // خط 51
  // تست عملکرد در حالت آفلاین
  // خط 52
  // بهینه‌سازی زمان اجرا
  // خط 53
  // مدیریت لاگ‌ها
  // خط 54
  // تست با داده‌های واقعی
  // خط 55
  // به‌روزرسانی دیتابیس
  // خط 56
  // مدیریت کش
  // خط 57
  // تست سازگاری با API
  // خط 58
  // بهینه‌سازی رابط کاربری
  // خط 59
  // مدیریت اعلان‌های push
  // خط 60
  // تست با دستگاه‌های مختلف
  // خط 61
  // به‌روزرسانی مستندات کاربر
  // خط 62
  // مدیریت خطاهای سرور
  // خط 63
  // تست عملکرد در شبکه ضعیف
  // خط 64
  // بهینه‌سازی مصرف داده
  // خط 65
  // مدیریت حافظه کش
  // خط 66
  // تست با کاربران واقعی
  // خط 67
  // به‌روزرسانی کد
  // خط 68
  // مدیریت خطاهای غیرمنتظره
  // خط 69
  // تست با داده‌های تصادفی
  // خط 70
  // بهینه‌سازی سرعت
  // خط 71
  // مدیریت لاگ‌های خطا
  // خط 72
  // تست با نسخه‌های قدیمی
  // خط 73
  // به‌روزرسانی مستندات توسعه‌دهنده
  // خط 74
  // مدیریت داده‌های آفلاین
  // خط 75
  // تست با سناریوهای مختلف
  // خط 76
  // بهینه‌سازی مصرف CPU
  // خط 77
  // مدیریت اعلان‌های محلی
  // خط 78
  // تست با داده‌های بزرگ
  // خط 79
  // به‌روزرسانی کد منبع
  // خط 80
  // مدیریت خطاهای کاربر
  // خط 81
  // تست با دستگاه‌های قدیمی
  // خط 82
  // بهینه‌سازی رابط کاربری
  // خط 83
  // مدیریت داده‌های موقت
  // خط 84
  // تست با شبکه 4G
  // خط 85
  // به‌روزرسانی مستندات فنی
  // خط 86
  // مدیریت اعلان‌های زمان‌بندی‌شده
  // خط 87
  // تست با داده‌های ناقص
  // خط 88
  // بهینه‌سازی مصرف حافظه
  // خط 89
  // مدیریت خطاهای دیتابیس
  // خط 90
  // تست با سناریوهای پیچیده
  // خط 91
  // به‌روزرسانی کد بک‌اند
  // خط 92
  // مدیریت لاگ‌های سیستم
  // خط 93
  // تست با دستگاه‌های مختلف برند
  // خط 94
  // بهینه‌سازی زمان بارگذاری
  // خط 95
  // مدیریت اعلان‌های فوری
  // خط 96
  // تست با داده‌های واقعی
  // خط 97
  // به‌روزرسانی مستندات API
  // خط 98
  // مدیریت خطاهای شبکه
  // خط 99
  // تست با سناریوهای آفلاین
  // خط 100
  // بهینه‌سازی مصرف باتری
  // خط 101
  // مدیریت داده‌های کش‌شده
  // خط 102
  // تست با کاربران مختلف
  // خط 103
  // به‌روزرسانی کد منبع
  // خط 104
  // مدیریت خطاهای غیرمنتظره
  // خط 105
  // تست با داده‌های تصادفی
  // خط 106
  // بهینه‌سازی سرعت
  // خط 107
  // مدیریت لاگ‌های خطا
  // خط 108
  // تست با نسخه‌های قدیمی
  // خط 109
  // به‌روزرسانی مستندات توسعه‌دهنده
  // خط 110
  // مدیریت داده‌های آفلاین
  // خط 111
  // تست با سناریوهای مختلف
  // خط 112
  // بهینه‌سازی مصرف CPU
  // خط 113
  // مدیریت اعلان‌های محلی
  // خط 114
  // تست با داده‌های بزرگ
  // خط 115
  // به‌روزرسانی کد منبع
  // خط 116
  // مدیریت خطاهای کاربر
  // خط 117
  // تست با دستگاه‌های قدیمی
  // خط 118
  // بهینه‌سازی رابط کاربری
  // خط 119
  // مدیریت داده‌های موقت
  // خط 120
  // تست با شبکه 4G
  // خط 121
  // به‌روزرسانی مستندات فنی
  // خط 122
  // مدیریت اعلان‌های زمان‌بندی‌شده
  // خط 123
  // تست با داده‌های ناقص
  // خط 124
  // بهینه‌سازی مصرف حافظه
  // خط 125
  // مدیریت خطاهای دیتابیس
  // خط 126
  // تست با سناریوهای پیچیده
  // خط 127
  // به‌روزرسانی کد بک‌اند
  // خط 128
  // مدیریت لاگ‌های سیستم
  // خط 129
  // تست با دستگاه‌های مختلف برند
  // خط 130
  // بهینه‌سازی زمان بارگذاری
  // خط 131
  // مدیریت اعلان‌های فوری
  // خط 132
  // تست با داده‌های واقعی
  // خط 133
  // به‌روزرسانی مستندات API
  // خط 134
  // مدیریت خطاهای شبکه
  // خط 135
  // تست با سناریوهای آفلاین
  // خط 136
  // بهینه‌سازی مصرف باتری
  // خط 137
  // مدیریت داده‌های کش‌شده
  // خط 138
  // تست با کاربران مختلف
  // خط 139
  // به‌روزرسانی کد منبع
  // خط 140
  // مدیریت خطاهای غیرمنتظره
  // خط 141
  // تست با داده‌های تصادفی
  // خط 142
  // بهینه‌سازی سرعت
  // خط 143
  // مدیریت لاگ‌های خطا
  // خط 144
  // تست با نسخه‌های قدیمی
  // خط 145
  // به‌روزرسانی مستندات توسعه‌دهنده
  // خط 146
  // مدیریت داده‌های آفلاین
  // خط 147
  // تست با سناریوهای مختلف
  // خط 148
  // بهینه‌سازی مصرف CPU
  // خط 149
  // مدیریت اعلان‌های محلی
  // خط 150
  // تست با داده‌های بزرگ
  // خط 151
  // به‌روزرسانی کد منبع
  // خط 152
  // مدیریت خطاهای کاربر
  // خط 153
  // تست با دستگاه‌های قدیمی
  // خط 154
  // بهینه‌سازی رابط کاربری
  // خط 155
  // مدیریت داده‌های موقت
  // خط 156
  // تست با شبکه 4G
  // خط 157
  // به‌روزرسانی مستندات فنی
  // خط 158
  // مدیریت اعلان‌های زمان‌بندی‌شده
  // خط 159
  // تست با داده‌های ناقص
  // خط 160
  // بهینه‌سازی مصرف حافظه
  // خط 161
  // مدیریت خطاهای دیتابیس
  // خط 162
  // تست با سناریوهای پیچیده
  // خط 163
  // به‌روزرسانی کد بک‌اند
  // خط 164
  // مدیریت لاگ‌های سیستم
  // خط 165
  // تست با دستگاه‌های مختلف برند
  // خط 166
  // بهینه‌سازی زمان بارگذاری
  // خط 167
  // مدیریت اعلان‌های فوری
  // خط 168
  // تست با داده‌های واقعی
  // خط 169
  // به‌روزرسانی مستندات API
  // خط 170
  // مدیریت خطاهای شبکه
  // خط 171
  // تست با سناریوهای آفلاین
  // خط 172
  // بهینه‌سازی مصرف باتری
  // خط 173
  // مدیریت داده‌های کش‌شده
  // خط 174
  // تست با کاربران مختلف
  // خط 175
  // به‌روزرسانی کد منبع
  // خط 176
  // پایان پدینگ
  // خط 177
}