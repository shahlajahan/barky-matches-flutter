import '../business/business_card_data.dart';

class VetCardData extends BusinessCardData {
  const VetCardData({
    required super.id,
    required super.name,
    required super.city,
    required super.district,
    required super.address,
    super.distanceKm,
    required super.specialties,
    super.services,
    super.phone,
    super.whatsapp,
    super.rating,
    super.reviewsCount,
    super.workingHours,
    super.description,
    super.isPartner,
    super.isVerified,
    super.is24h,
    super.isEmergency,
  }) : super(type: BusinessType.vet);
}