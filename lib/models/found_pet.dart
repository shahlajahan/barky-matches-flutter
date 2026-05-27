import 'package:cloud_firestore/cloud_firestore.dart';
import 'lost_pet.dart';

class FoundPet {
  final String id;
  final String name;
  final String breed;
  final String petType;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final String reportedBy;
  final String ownerId;
  final String? color;
  final String? weight;
  final String? collarType;
  final String? clothingColor;
  final String foundLocation;
  final Map<String, dynamic> contactInfo;
  final String? description;
  final bool isClaimed;
  final String? imageUrl;

  FoundPet({
    this.id = '',
    required this.name,
    required this.breed,
    this.petType = 'dog',
    required this.latitude,
    required this.longitude,
    required this.reportedAt,
    required this.reportedBy,
    required this.ownerId,
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
      'foundLocation': foundLocation,
      'contactInfo': contactInfo,
      'description': description,
      'isClaimed': isClaimed,
      'imageUrl': imageUrl,
    };
  }

  factory FoundPet.fromMap(Map<String, dynamic> map) {
    DateTime parseReportedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return FoundPet(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      breed: map['breed'] as String? ?? '',
      petType: normalizePetType(map['petType']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      reportedAt: parseReportedAt(map['reportedAt']),
      reportedBy: map['reportedBy'] as String? ?? '',
      ownerId:
          map['ownerId']?.toString() ?? map['reportedBy']?.toString() ?? '',
      color: map['color'] as String?,
      weight: map['weight'] as String?,
      collarType: map['collarType'] as String?,
      clothingColor: map['clothingColor'] as String?,
      foundLocation: map['foundLocation'] as String? ?? '',
      contactInfo:
          parseContactInfo(map['contactInfo']) ?? {'type': '', 'value': ''},
      description: map['description'] as String?,
      isClaimed: map['isClaimed'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  FoundPet copyWith({
    String? id,
    String? name,
    String? breed,
    String? petType,
    double? latitude,
    double? longitude,
    DateTime? reportedAt,
    String? reportedBy,
    String? ownerId,
    String? color,
    String? weight,
    String? collarType,
    String? clothingColor,
    String? foundLocation,
    Map<String, dynamic>? contactInfo,
    String? description,
    bool? isClaimed,
    String? imageUrl,
  }) {
    return FoundPet(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      petType: petType ?? this.petType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reportedAt: reportedAt ?? this.reportedAt,
      reportedBy: reportedBy ?? this.reportedBy,
      ownerId: ownerId ?? this.ownerId,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      collarType: collarType ?? this.collarType,
      clothingColor: clothingColor ?? this.clothingColor,
      foundLocation: foundLocation ?? this.foundLocation,
      contactInfo: contactInfo ?? this.contactInfo,
      description: description ?? this.description,
      isClaimed: isClaimed ?? this.isClaimed,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
