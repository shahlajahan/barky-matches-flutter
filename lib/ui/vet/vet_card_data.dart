import '../business/business_card_data.dart';

class VetCardData extends BusinessCardData {
  final String? instagram;
  final String? website;
  final String? logoUrl;
  final String? coverImageUrl;
  
final Map<String, dynamic>? rawData;
  // 🔥 NEW
  final Map<String, dynamic>? sectorData;

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

  required BusinessType type,

  this.instagram,
  this.website,
  this.logoUrl,
  this.coverImageUrl,
  this.rawData,

  this.sectorData,
}) : super(
       type: type,
     );

  // 🔥 VERY IMPORTANT
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'district': district,
      'address': address,
      'distanceKm': distanceKm,
      'specialties': specialties,
      'services': services,
      'phone': phone,
      'whatsapp': whatsapp,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'workingHours': workingHours,
      'description': description,
      'instagram': instagram,
      'website': website,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'isPartner': isPartner,
      'isVerified': isVerified,
      'is24h': is24h,
      'isEmergency': isEmergency,

      // 🔥 THIS FIXES EVERYTHING
      'sectorData': sectorData,
    };
  }
}