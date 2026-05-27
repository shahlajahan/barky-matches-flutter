import 'package:cloud_firestore/cloud_firestore.dart';

class LostPet {
  final String id;
  final String name;
  final String breed;
  final String petType;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final String ownerId;
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
  final String? imageUrl;
  final String? gender;
  final String? healthStatus;

  LostPet({
    this.id = '',
    required this.name,
    required this.breed,
    this.petType = 'dog',
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
    required this.ownerId,
    this.isFound = false,
    this.age,
    this.imageUrl,
    this.gender,
    this.healthStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'petType': normalizePetType(petType),
      'latitude': latitude,
      'longitude': longitude,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'reportedBy': reportedBy,
      'ownerId': ownerId,
      'color': color,
      'weight': weight,
      'collarType': collarType,
      'clothingColor': clothingColor,
      'lostLocation': lostLocation,
      'contactInfo': contactInfo,
      'description': description,
      'isFound': isFound,
      'age': age,
      'imageUrl': imageUrl,
      'gender': gender,
      'healthStatus': healthStatus,
    };
  }

  factory LostPet.fromMap(Map<String, dynamic> map) {
    DateTime parseReportedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return LostPet(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      breed: map['breed'] as String? ?? '',
      petType: normalizePetType(map['petType']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      reportedAt: parseReportedAt(map['reportedAt']),
      reportedBy: map['reportedBy'] as String? ?? '',
      ownerId: map['ownerId']?.toString() ?? '',
      color: map['color'] as String?,
      weight: map['weight'] as String?,
      collarType: map['collarType'] as String?,
      clothingColor: map['clothingColor'] as String?,
      lostLocation: map['lostLocation'] as String? ?? '',
      contactInfo: parseContactInfo(map['contactInfo']),
      description: map['description'] as String?,
      isFound: map['isFound'] as bool? ?? false,
      age: (map['age'] as num?)?.toInt(),
      imageUrl: map['imageUrl'] as String?,
      gender: map['gender'] as String?,
      healthStatus: map['healthStatus'] as String?,
    );
  }

  LostPet copyWith({
    String? id,
    String? name,
    String? breed,
    String? petType,
    double? latitude,
    double? longitude,
    DateTime? reportedAt,
    String? reportedBy,
    String? color,
    String? weight,
    String? collarType,
    String? ownerId,
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
    return LostPet(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      petType: petType ?? this.petType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reportedAt: reportedAt ?? this.reportedAt,
      reportedBy: reportedBy ?? this.reportedBy,
      color: color ?? this.color,
      ownerId: ownerId ?? this.ownerId,
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

Map<String, dynamic>? parseContactInfo(dynamic value) {
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) return {'type': 'phone', 'value': value};
  return null;
}

String normalizePetType(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  const supported = {'dog', 'cat', 'bird', 'rabbit', 'other'};
  return supported.contains(normalized) ? normalized : 'dog';
}

String normalizedContactType(dynamic value) {
  return value?.toString().trim().toLowerCase() ?? '';
}
