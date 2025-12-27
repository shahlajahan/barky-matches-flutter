import 'package:cloud_firestore/cloud_firestore.dart';

class LostDog {
  final String id; // اختیاری، برای شناسایی سند
  final String name;
  final String breed;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final String reportedBy;
  final String? color; // اختیاری
  final String? weight; // اختیاری
  final String? collarType; // اختیاری
  final String? clothingColor; // اختیاری
  final String lostLocation; // الزامی
  final String contactInfo; // الزامی
  final String? description; // اختیاری
  final bool isFound; // جدید

  LostDog({
    this.id = '',
    required this.name,
    required this.breed,
    required this.latitude,
    required this.longitude,
    required this.reportedAt,
    required this.reportedBy,
    this.color,
    this.weight,
    this.collarType,
    this.clothingColor,
    required this.lostLocation,
    required this.contactInfo,
    this.description,
    this.isFound = false, // پیش‌فرض false
  });

  // تبدیل داده‌ها به Map برای ذخیره در Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'latitude': latitude,
      'longitude': longitude,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'reportedBy': reportedBy,
      'color': color,
      'weight': weight,
      'collarType': collarType,
      'clothingColor': clothingColor,
      'lostLocation': lostLocation,
      'contactInfo': contactInfo,
      'description': description,
      'isFound': isFound,
    };
  }

  // ساخت شیء از Map (مثلاً از داده‌های Firestore) با مدیریت انواع مختلف
  factory LostDog.fromMap(Map<String, dynamic> map) {
    DateTime parseReportedAt(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing reportedAt string: $e');
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return LostDog(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      breed: map['breed'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      reportedAt: parseReportedAt(map['reportedAt']),
      reportedBy: map['reportedBy'] as String? ?? '',
      color: map['color'] as String?,
      weight: map['weight'] as String?,
      collarType: map['collarType'] as String?,
      clothingColor: map['clothingColor'] as String?,
      lostLocation: map['lostLocation'] as String? ?? '',
      contactInfo: map['contactInfo'] as String? ?? '',
      description: map['description'] as String?,
      isFound: map['isFound'] as bool? ?? false,
    );
  }

  // متد copyWith برای کپی با تغییرات
  LostDog copyWith({
    String? id,
    String? name,
    String? breed,
    double? latitude,
    double? longitude,
    DateTime? reportedAt,
    String? reportedBy,
    String? color,
    String? weight,
    String? collarType,
    String? clothingColor,
    String? lostLocation,
    String? contactInfo,
    String? description,
    bool? isFound,
  }) {
    return LostDog(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reportedAt: reportedAt ?? this.reportedAt,
      reportedBy: reportedBy ?? this.reportedBy,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      collarType: collarType ?? this.collarType,
      clothingColor: clothingColor ?? this.clothingColor,
      lostLocation: lostLocation ?? this.lostLocation,
      contactInfo: contactInfo ?? this.contactInfo,
      description: description ?? this.description,
      isFound: isFound ?? this.isFound,
    );
  }
}