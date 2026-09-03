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
      'pethotel' || 'hotel' || 'boarding' || 'petboarding' => petHotel,
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

  /// Returns true only when the canonical `sectors` field declares the sector.
  /// Other fields, including sectorData, are intentionally ignored.
  static bool hasCanonicalSector(
    Map<String, dynamic> business,
    String canonical,
  ) {
    return _values(
      business['sectors'],
    ).any((value) => normalize(value) == canonical);
  }

  /// Returns true only when [business] authoritatively belongs to [canonical].
  ///
  /// Membership may be established by exactly two things:
  ///
  /// 1. the canonical `sectors` array, normalized through [normalize]; and
  /// 2. a top-level key of the sector-detail map — `sectorData`, or its
  ///    published mirror `publicSectorData` — that itself normalizes to
  ///    [canonical]. This second source exists only so documents written
  ///    before `sectors` became canonical stay visible in their own list.
  ///
  /// Values nested underneath those keys are never inspected, and neither is
  /// any other field. A Pet Shop's `shopTypes: ['Grooming']`, its categories,
  /// brands, tags, service names and free-text description are product data,
  /// not sector membership: they must never place the shop in the Groomy
  /// list. The same holds for a shop that merely mentions "hotel",
  /// "boarding" or "pansiyon" somewhere in its own content.
  static bool belongsToSector(Map<String, dynamic> business, String canonical) {
    if (hasCanonicalSector(business, canonical)) return true;
    return _sectorDataKeys(business).any((key) => normalize(key) == canonical);
  }

  /// Top-level sector keys across both stored representations.
  ///
  /// `businesses/{id}` stores sector details under `sectorData`; the public
  /// projection republishes the same map as `publicSectorData`. Anything that
  /// is not a map contributes no keys, so malformed documents fail closed.
  static Iterable<String> _sectorDataKeys(Map<String, dynamic> business) {
    final keys = <String>[];
    for (final source in [
      business['sectorData'],
      business['publicSectorData'],
    ]) {
      if (source is! Map) continue;
      for (final key in source.keys) {
        keys.add(key.toString());
      }
    }
    return keys;
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
