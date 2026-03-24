enum BusinessType {
  vet,
  adoptionCenter,
  petShop,
  groomer,
}

class BusinessCardData {
  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final double? distanceKm;

  final List<String> specialties;
  final List<String>? services;

  final String? phone;
  final String? whatsapp;

  final double? rating;
  final int? reviewsCount;

  final Map<String, String>? workingHours;
  final String? description;

  final bool isPartner;

  final bool isVerified;
  final String status;
  final bool is24h;
  final bool isEmergency;

  final BusinessType type;

  

  const BusinessCardData({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    this.distanceKm,
    required this.specialties,
    this.services,
    this.phone,
    this.whatsapp,
    this.rating,
    this.reviewsCount,
    this.workingHours,
    this.description,
    this.isPartner = false,
    this.isVerified = false,
    this.status = "approved",
    this.is24h = false,
    this.isEmergency = false,
    required this.type,
  });
}


