// lib/core/business_enums.dart

enum BusinessType {
  adoptionCenter,
  petShop,
  groomer,
  petHotel,
  trainer,
  veterinarian,
}

enum BusinessStatus {
  none,
  pending,
  approved,
  rejected,
  suspended,
}

// 🔹 Mapper → Firestore string (lowercase_with_underscore)
extension BusinessTypeX on BusinessType {
  String get firestoreValue {
    switch (this) {
      case BusinessType.adoptionCenter:
        return 'adoption_center';
      case BusinessType.petShop:
        return 'pet_shop';
      case BusinessType.groomer:
        return 'groomer';
      case BusinessType.petHotel:
        return 'pet_hotel';
      case BusinessType.trainer:
        return 'trainer';
      case BusinessType.veterinarian:
        return 'veterinarian';
    }
  }

  static BusinessType fromFirestore(String value) {
    switch (value) {
      case 'adoption_center':
        return BusinessType.adoptionCenter;
      case 'pet_shop':
        return BusinessType.petShop;
      case 'groomer':
        return BusinessType.groomer;
      case 'pet_hotel':
        return BusinessType.petHotel;
      case 'trainer':
        return BusinessType.trainer;
      case 'veterinarian':
        return BusinessType.veterinarian;
      default:
        throw Exception('Unknown BusinessType: $value');
    }
  }
}

extension BusinessStatusX on BusinessStatus {
  String get firestoreValue {
    return name; // pending / approved / rejected ...
  }

  static BusinessStatus fromFirestore(String value) {
    return BusinessStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BusinessStatus.none,
    );
  }
}