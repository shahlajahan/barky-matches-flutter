import 'package:cloud_firestore/cloud_firestore.dart';

class AdoptionPetStatus {
  static const available = 'available';
  static const reserved = 'reserved';
  static const adopted = 'adopted';
  static const paused = 'paused';

  static const values = [
    available,
    reserved,
    adopted,
    paused,
  ];
}

class AdoptionPetModel {
  final String id;

  final String businessId;

  final String name;

  final String species;

  final String breed;

  final int ageMonths;

  final String gender;

  final String description;

  final String status;

  final String? coverImageUrl;

  final List<String> gallery;

  final bool isVisible;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final DateTime? adoptedAt;

  const AdoptionPetModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.species,
    required this.breed,
    required this.ageMonths,
    required this.gender,
    required this.description,
    required this.status,
    required this.coverImageUrl,
    required this.gallery,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
    required this.adoptedAt,
  });

  factory AdoptionPetModel.empty({
    required String businessId,
  }) {
    return AdoptionPetModel(
      id: '',
      businessId: businessId,
      name: '',
      species: '',
      breed: '',
      ageMonths: 0,
      gender: '',
      description: '',
      status: AdoptionPetStatus.available,
      coverImageUrl: null,
      gallery: const [],
      isVisible: true,
      createdAt: null,
      updatedAt: null,
      adoptedAt: null,
    );
  }

  factory AdoptionPetModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    DateTime? _parse(dynamic value) {
      if (value == null) return null;

      if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    }

    return AdoptionPetModel(
      id: doc.id,

      businessId:
          (data['businessId'] ?? '').toString(),

      name:
          (data['name'] ?? '').toString(),

      species:
          (data['species'] ?? '').toString(),

      breed:
          (data['breed'] ?? '').toString(),

      ageMonths:
          (data['ageMonths'] ?? 0) is int
              ? data['ageMonths']
              : int.tryParse(
                    data['ageMonths'].toString(),
                  ) ??
                  0,

      gender:
          (data['gender'] ?? '').toString(),

      description:
          (data['description'] ?? '').toString(),

      status:
          AdoptionPetStatus.values.contains(
            data['status'],
          )
              ? data['status']
              : AdoptionPetStatus.available,

      coverImageUrl:
          data['coverImageUrl']?.toString(),

      gallery:
          List<String>.from(
        data['gallery'] ?? [],
      ),

      isVisible:
          data['isVisible'] ?? true,

      createdAt:
          _parse(data['createdAt']),

      updatedAt:
          _parse(data['updatedAt']),

      adoptedAt:
          _parse(data['adoptedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,

      'name': name,

      'species': species,

      'breed': breed,

      'ageMonths': ageMonths,

      'gender': gender,

      'description': description,

      'status': status,

      'coverImageUrl': coverImageUrl,

      'gallery': gallery,

      'isVisible': isVisible,

      'createdAt':
          createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(createdAt!),

      'updatedAt':
          FieldValue.serverTimestamp(),

      'adoptedAt':
          adoptedAt == null
              ? null
              : Timestamp.fromDate(adoptedAt!),
    };
  }

  AdoptionPetModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? species,
    String? breed,
    int? ageMonths,
    String? gender,
    String? description,
    String? status,
    String? coverImageUrl,
    List<String>? gallery,
    bool? isVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? adoptedAt,
  }) {
    return AdoptionPetModel(
      id: id ?? this.id,

      businessId:
          businessId ?? this.businessId,

      name:
          name ?? this.name,

      species:
          species ?? this.species,

      breed:
          breed ?? this.breed,

      ageMonths:
          ageMonths ?? this.ageMonths,

      gender:
          gender ?? this.gender,

      description:
          description ?? this.description,

      status:
          status ?? this.status,

      coverImageUrl:
          coverImageUrl ?? this.coverImageUrl,

      gallery:
          gallery ?? this.gallery,

      isVisible:
          isVisible ?? this.isVisible,

      createdAt:
          createdAt ?? this.createdAt,

      updatedAt:
          updatedAt ?? this.updatedAt,

      adoptedAt:
          adoptedAt ?? this.adoptedAt,
    );
  }

  String get ageLabel {
    if (ageMonths < 12) {
      return '$ageMonths months';
    }

    final years =
        (ageMonths / 12).floor();

    final remaining =
        ageMonths % 12;

    if (remaining == 0) {
      return '$years years';
    }

    return '$years y $remaining m';
  }

  bool get isAdopted =>
      status == AdoptionPetStatus.adopted;

  bool get isAvailable =>
      status == AdoptionPetStatus.available;
}