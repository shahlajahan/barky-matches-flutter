import 'package:cloud_firestore/cloud_firestore.dart';

class LostDog {
  final String id;
  final String name;
  final String breed;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final String reportedBy;

  final String? color;
  final String? weight;
  final String? collarType;
  final String? clothingColor;
  final String lostLocation;
  final Map<String, dynamic>? contactInfo;
  final String? description;
  final bool isFound;
final int? age;

  // ✅ NEW FIELDS
  final String? imageUrl;
  final String? gender;
  final String? healthStatus;

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
    this.contactInfo,
    this.description,
    this.isFound = false,
    this.age,
    

    // 👇 مهم — این‌ها باید داخل constructor باشند
    this.imageUrl,
    this.gender,
    this.healthStatus,
  });

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
      'age': age,

      // ✅ NEW
      'imageUrl': imageUrl,
      'gender': gender,
      'healthStatus': healthStatus,
    };
  }

  factory LostDog.fromMap(Map<String, dynamic> map) {
    DateTime parseReportedAt(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
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
      contactInfo: map['contactInfo'] is Map
          ? Map<String, dynamic>.from(map['contactInfo'])
          : map['contactInfo'] is String
              ? {"type": "legacy", "value": map['contactInfo']}
              : null,
      description: map['description'] as String?,
      isFound: map['isFound'] as bool? ?? false,
      age: (map['age'] as num?)?.toInt(),

      // ✅ NEW SAFE
      imageUrl: map['imageUrl'] as String?,
      gender: map['gender'] as String?,
      healthStatus: map['healthStatus'] as String?,
    );
  }

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
    Map<String, dynamic>? contactInfo,
    String? description,
    bool? isFound,
    int? age,
    String? imageUrl,
    String? gender,
    String? healthStatus,
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
      imageUrl: imageUrl ?? this.imageUrl,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      healthStatus: healthStatus ?? this.healthStatus,
    );
  }
}