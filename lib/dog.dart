
import 'package:hive/hive.dart';

part 'dog.g.dart';

@HiveType(typeId: 0)
class Dog extends HiveObject {
  @HiveField(0)
  String id; // فیلد جدید id

  @HiveField(1)
  String name;

  @HiveField(2)
  String breed;

  @HiveField(3)
  int age;

  @HiveField(4)
  String gender;

  @HiveField(5)
  String healthStatus;

  @HiveField(6)
  bool isNeutered;

  @HiveField(7)
  String? description;

  @HiveField(8)
  List<String> traits;

  @HiveField(9)
  String? ownerGender;

  @HiveField(10)
  List<String> imagePaths;

  @HiveField(11)
  bool isAvailableForAdoption;

  @HiveField(12)
  bool isOwner;

  @HiveField(13)
  String? ownerId;

  @HiveField(14)
  double? latitude;

  @HiveField(15)
  double? longitude;

  Dog({
    required this.id, // اضافه کردن id به سازنده
    required this.name,
    required this.breed,
    required this.age,
    required this.gender,
    required this.healthStatus,
    required this.isNeutered,
    this.description,
    required this.traits,
    this.ownerGender,
    required this.imagePaths,
    required this.isAvailableForAdoption,
    required this.isOwner,
    this.ownerId,
    this.latitude,
    this.longitude,
  });

  factory Dog.fromMap(Map<String, dynamic> map) {
    return Dog(
      id: map['id'] ?? '', // اضافه کردن id
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      age: (map['age'] ?? 0) as int,
      gender: map['gender'] ?? '',
      healthStatus: map['healthStatus'] ?? '',
      isNeutered: map['isNeutered'] ?? false,
      description: map['description'] as String?,
      traits: List<String>.from(map['traits'] ?? []),
      ownerGender: map['ownerGender'] as String?,
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      isAvailableForAdoption: map['isAvailableForAdoption'] ?? false,
      isOwner: map['isOwner'] ?? false,
      ownerId: map['ownerId'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // اضافه کردن id
      'name': name,
      'breed': breed,
      'age': age,
      'gender': gender,
      'healthStatus': healthStatus,
      'isNeutered': isNeutered,
      'description': description,
      'traits': traits,
      'ownerGender': ownerGender,
      'imagePaths': imagePaths,
      'isAvailableForAdoption': isAvailableForAdoption,
      'isOwner': isOwner,
      'ownerId': ownerId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Dog copy({
    String? id, // اضافه کردن id
    String? name,
    String? breed,
    int? age,
    String? gender,
    String? healthStatus,
    bool? isNeutered,
    String? description,
    List<String>? traits,
    String? ownerGender,
    List<String>? imagePaths,
    bool? isAvailableForAdoption,
    bool? isOwner,
    String? ownerId,
    double? latitude,
    double? longitude,
  }) =>
      Dog(
        id: id ?? this.id, // استفاده از id
        name: name ?? this.name,
        breed: breed ?? this.breed,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        healthStatus: healthStatus ?? this.healthStatus,
        isNeutered: isNeutered ?? this.isNeutered,
        description: description ?? this.description,
        traits: traits != null ? List.from(traits) : List.from(this.traits),
        ownerGender: ownerGender ?? this.ownerGender,
        imagePaths: imagePaths != null ? List.from(imagePaths) : List.from(this.imagePaths),
        isAvailableForAdoption: isAvailableForAdoption ?? this.isAvailableForAdoption,
        isOwner: isOwner ?? this.isOwner,
        ownerId: ownerId ?? this.ownerId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}