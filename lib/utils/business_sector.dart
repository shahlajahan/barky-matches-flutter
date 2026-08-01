enum BusinessSectorDestination {
  businessDetails,
  petTaxiBooking,
  trainingUnavailable,
  unavailable,
}

/// Canonical business-sector values used by application logic and navigation.
abstract final class BusinessSector {
  static const String vet = 'vet';
  static const String groomy = 'groomy';
  static const String petShop = 'pet_shop';
  static const String petHotel = 'pet_hotel';
  static const String petTaxi = 'pet_taxi';
  static const String adoptionCenter = 'adoption_center';
  static const String training = 'training';

  static const Set<String> values = {
    vet,
    groomy,
    petShop,
    petHotel,
    petTaxi,
    adoptionCenter,
    training,
  };

  static String? normalize(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[-\s]+'),
      '_',
    );
    if (normalized == null || normalized.isEmpty) return null;

    final compact = normalized.replaceAll('_', '');
    return switch (compact) {
      'vet' || 'veterinary' || 'veterinaryclinic' || 'clinic' => vet,
      'groomy' || 'groomer' || 'grooming' || 'petgrooming' => groomy,
      'petshop' || 'seller' || 'petstore' => petShop,
      'pethotel' || 'boarding' || 'petboarding' => petHotel,
      'pettaxi' || 'taxi' => petTaxi,
      'adoptioncenter' || 'adoption' => adoptionCenter,
      'training' || 'trainer' || 'dogtraining' || 'pettraining' => training,
      _ => null,
    };
  }

  static String? fromBusiness(Map<String, dynamic> business) {
    final sectorData = _map(business['sectorData']);
    final profile = _map(business['profile']);

    for (final candidate in [
      ...sectorData.keys,
      ..._values(business['sector']),
      ..._values(business['sectors']),
      ..._values(business['businessType']),
      ..._values(business['category']),
      ..._values(business['type']),
      ..._values(profile['businessType']),
      ..._values(profile['category']),
      ..._values(profile['categories']),
    ]) {
      final canonical = normalize(candidate);
      if (canonical != null) return canonical;
    }
    return null;
  }

  static String rawValue(Map<String, dynamic> business) {
    final sectorData = _map(business['sectorData']);
    return [
          business['sector'],
          business['sectors'],
          business['businessType'],
          business['category'],
          business['type'],
          if (sectorData.isNotEmpty) sectorData.keys.join(','),
        ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' | ');
  }

  static List<String> searchAliases(String? canonical) {
    return switch (canonical) {
      vet => const ['vet', 'veterinary', 'clinic'],
      groomy => const ['groomy', 'groomer', 'grooming', 'pet kuaför'],
      petShop => const ['pet shop', 'petshop', 'seller', 'pet store'],
      petHotel => const ['pet hotel', 'hotel', 'boarding', 'pansiyon'],
      petTaxi => const ['pet taxi', 'pettaxi', 'taxi'],
      adoptionCenter => const ['adoption center', 'adoption', 'adoptioncentre'],
      training => const ['training', 'trainer', 'dog training', 'pet training'],
      _ => const [],
    };
  }

  static BusinessSectorDestination destination(String? canonical) {
    return switch (canonical) {
      vet ||
      groomy ||
      petShop ||
      petHotel ||
      adoptionCenter => BusinessSectorDestination.businessDetails,
      petTaxi => BusinessSectorDestination.petTaxiBooking,
      training => BusinessSectorDestination.trainingUnavailable,
      _ => BusinessSectorDestination.unavailable,
    };
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  static Iterable<dynamic> _values(dynamic value) {
    return value is Iterable ? value : [value];
  }
}
