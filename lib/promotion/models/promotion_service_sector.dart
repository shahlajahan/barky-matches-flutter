/// Real service sectors represented by the application domain.
///
/// M7 enables only sectors with individual service records, an owner-facing
/// management surface, and a service-level discovery consumer.
enum PromotionServiceSector {
  vet('VET', true),
  groomer('GROOMER', true),
  petHotel('PET_HOTEL', false),
  petTaxi('PET_TAXI', false);

  const PromotionServiceSector(this.value, this.m7Enabled);

  final String value;
  final bool m7Enabled;

  static PromotionServiceSector fromValue(Object? value) {
    final normalized = value?.toString().trim().toUpperCase();
    return values.firstWhere(
      (sector) => sector.value == normalized,
      orElse: () => throw FormatException('Unknown service sector: $value'),
    );
  }
}

/// Stable, collision-resistant SERVICE identity.
///
/// Service documents live below a business and document IDs can repeat across
/// businesses/sectors. The canonical target therefore includes both path
/// segments. Firestore document IDs cannot contain '/', so parsing is exact.
class PromotionServiceTargetId {
  const PromotionServiceTargetId({
    required this.sector,
    required this.businessId,
    required this.serviceId,
  });

  final PromotionServiceSector sector;
  final String businessId;
  final String serviceId;

  String get value => 'service/${sector.value}/$businessId/$serviceId';

  static PromotionServiceTargetId? parse(String value) {
    final parts = value.split('/');
    if (parts.length != 4 || parts.first != 'service') return null;
    if (parts[1].isEmpty || parts[2].isEmpty || parts[3].isEmpty) return null;
    return PromotionServiceTargetId(
      sector: PromotionServiceSector.fromValue(parts[1]),
      businessId: parts[2],
      serviceId: parts[3],
    );
  }
}
