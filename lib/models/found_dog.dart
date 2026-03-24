import 'package:cloud_firestore/cloud_firestore.dart';

class FoundDog {
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
  final String foundLocation;
  final Map<String, dynamic> contactInfo; // ✅ FIXED
  final String? description;
  final bool isClaimed;
  final String? imageUrl;

  FoundDog({
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
    required this.foundLocation,
    required this.contactInfo,
    this.description,
    this.isClaimed = false,
    this.imageUrl,
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
      'foundLocation': foundLocation,
      'contactInfo': contactInfo,
      'description': description,
      'isClaimed': isClaimed,
      'imageUrl': imageUrl,
    };
  }

  factory FoundDog.fromMap(Map<String, dynamic> map) {
    DateTime parseReportedAt(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return FoundDog(
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
      foundLocation: map['foundLocation'] as String? ?? '',
      contactInfo: _parseContactInfo(map['contactInfo']),
      description: map['description'] as String?,
      isClaimed: map['isClaimed'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  FoundDog copyWith({
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
    String? foundLocation,
    Map<String, dynamic>? contactInfo, // ✅ FIXED
    String? description,
    bool? isClaimed,
    String? imageUrl,
  }) {
    return FoundDog(
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
      foundLocation: foundLocation ?? this.foundLocation,
      contactInfo: contactInfo ?? this.contactInfo, // ✅ FIXED
      description: description ?? this.description,
      isClaimed: isClaimed ?? this.isClaimed,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
static Map<String, dynamic> _parseContactInfo(dynamic value) {
  if (value == null) {
    return {
      "type": "",
      "value": "",
    };
  }

  // اگر قبلاً Map بوده
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  // اگر قبلاً String بوده (نسخه قدیمی دیتابیس)
  if (value is String) {
    return {
      "type": "Phone",
      "value": value,
    };
  }

  return {
    "type": "",
    "value": "",
  };
}

}