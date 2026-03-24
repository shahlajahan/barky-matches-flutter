import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/utils/firestore_cleaner.dart';

part 'dog.g.dart';

@HiveType(typeId: 0)
class Dog extends HiveObject {
  // =====================================================
  // 🧠 Safe Converters (Firestore / Map)
  // =====================================================

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // =====================================================
  // 🐶 Hive Fields
  // =====================================================

  @HiveField(0)
  String id;

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
// ❗ runtime only (NOT stored in Hive)
double? distanceKm;
  // =====================================================
// 🛡 Trust & Safety
// =====================================================

@HiveField(16)
int reportCount;

@HiveField(17)
bool isHidden;

@HiveField(18)
String moderationStatus;

@HiveField(19)
bool ownerProfileVisible;

@HiveField(20)
bool dogProfileVisible;

  // =====================================================
  // 🏗 Constructor
  // =====================================================

  Dog({
  required this.id,
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
  

  // Trust & Safety
  this.reportCount = 0,
  this.isHidden = false,
  this.moderationStatus = "active",

  // 🔐 Privacy
  this.ownerProfileVisible = true,
  this.dogProfileVisible = true,
});

  // =====================================================
  // 🔥 Firestore → Dog
  // =====================================================

  factory Dog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception(
        'Dog.fromFirestore: document data is null (docId: ${doc.id})',
      );
    }

    return Dog(
      id: doc.id,
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: data['gender'] ?? '',
      healthStatus: data['healthStatus'] ?? '',
      isNeutered: Dog._asBool(data['isNeutered']),
      description: data['description'],
      traits: List<String>.from(data['traits'] ?? const []),
      ownerGender: data['ownerGender'],
      imagePaths: List<String>.from(data['imagePaths'] ?? const []),
      isAvailableForAdoption:
          Dog._asBool(data['isAvailableForAdoption']),
      isOwner: Dog._asBool(data['isOwner']),
      ownerId: data['ownerUid'] ?? data['ownerId'],
      latitude: Dog._asDouble(data['latitude']),
      longitude: Dog._asDouble(data['longitude']),
      reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
isHidden: Dog._asBool(data['isHidden']),
moderationStatus: data['moderationStatus'] ?? "active",
ownerProfileVisible: Dog._asBool(data['ownerProfileVisible']),
dogProfileVisible: Dog._asBool(data['dogProfileVisible']),
    );
  }

  // =====================================================
  // 🧠 Map + id → Dog
  // =====================================================

  factory Dog.fromMap(Map<String, dynamic> map, String id) {
    return Dog(
      id: id,
      name: map['name'] is String && (map['name'] as String).isNotEmpty
    ? map['name']
    : '',
      breed: map['breed'] ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      gender: map['gender'] ?? '',
      healthStatus: map['healthStatus'] ?? '',
      isNeutered: Dog._asBool(map['isNeutered']),
      description: map['description'],
      traits: List<String>.from(map['traits'] ?? const []),
      ownerGender: map['ownerGender'],
      imagePaths: List<String>.from(map['imagePaths'] ?? const []),
      isAvailableForAdoption:
          Dog._asBool(map['isAvailableForAdoption']),
      isOwner: Dog._asBool(map['isOwner']),
      ownerId: map['ownerId'],
      latitude: Dog._asDouble(map['latitude']),
      longitude: Dog._asDouble(map['longitude']),
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
isHidden: Dog._asBool(map['isHidden']),
moderationStatus: map['moderationStatus'] ?? "active",
ownerProfileVisible: Dog._asBool(map['ownerProfileVisible']),
dogProfileVisible: Dog._asBool(map['dogProfileVisible']),
    );
  }

  // =====================================================
  // 🔄 Dog → Map (Firestore / Hive)
  // =====================================================

  Map<String, dynamic> toMap() {
    return {
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
      'reportCount': reportCount,
'isHidden': isHidden,
'moderationStatus': moderationStatus,
'ownerProfileVisible': ownerProfileVisible,
'dogProfileVisible': dogProfileVisible,
    };
  }

  // =====================================================
  // ✏️ Immutable Copy
  // =====================================================

  Dog copy({
    String? id,
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
    int? reportCount,
bool? isHidden,
String? moderationStatus,
bool? ownerProfileVisible,
bool? dogProfileVisible,
  }) {
    return Dog(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      healthStatus: healthStatus ?? this.healthStatus,
      isNeutered: isNeutered ?? this.isNeutered,
      description: description ?? this.description,
      traits: traits != null ? List.from(traits) : List.from(this.traits),
      ownerGender: ownerGender ?? this.ownerGender,
      imagePaths:
          imagePaths != null ? List.from(imagePaths) : List.from(this.imagePaths),
      isAvailableForAdoption:
          isAvailableForAdoption ?? this.isAvailableForAdoption,
      isOwner: isOwner ?? this.isOwner,
      ownerId: ownerId ?? this.ownerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reportCount: reportCount ?? this.reportCount,
isHidden: isHidden ?? this.isHidden,
moderationStatus: moderationStatus ?? this.moderationStatus,
ownerProfileVisible:
    ownerProfileVisible ?? this.ownerProfileVisible,

dogProfileVisible:
    dogProfileVisible ?? this.dogProfileVisible,
    );
  }
}
