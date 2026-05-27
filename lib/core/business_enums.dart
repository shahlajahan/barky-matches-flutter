// lib/core/business_enums.dart

enum BusinessType { vet, adoptionCenter, petShop, groomer, petHotel, trainer }

enum BusinessStatus { none, pending, approved, rejected, suspended }

extension BusinessTypeX on BusinessType {
  String get firestoreValue {
    switch (this) {
      case BusinessType.vet:
        return 'veterinarian';

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
    }
  }

  static BusinessType fromFirestore(String value) {
    switch (value) {
      case 'veterinarian':
        return BusinessType.vet;

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

      default:
        throw Exception('Unknown BusinessType: $value');
    }
  }
}

extension BusinessStatusX on BusinessStatus {
  String get firestoreValue {
    return name;
  }

  static BusinessStatus fromFirestore(String value) {
    return BusinessStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BusinessStatus.none,
    );
  }
}
