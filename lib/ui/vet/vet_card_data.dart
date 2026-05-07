import '../business/business_card_data.dart';

class VetCardData extends BusinessCardData {
  final String? instagram;
  final String? website;
  final String? logoUrl;
  final String? coverImageUrl;

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

    this.instagram,
    this.website,
    this.logoUrl,
    this.coverImageUrl,
  }) : super(type: BusinessType.vet);
}