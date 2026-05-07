import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../business/business_card.dart';
import '../business/business_card_data.dart';
import 'vet_card_data.dart';

class VetCard extends StatelessWidget {
  final VetCardData data;

  final VoidCallback? onTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onDirectionsTap;

  const VetCard({
    super.key,
    required this.data,
    this.onTap,
    this.onCallTap,
    this.onWhatsAppTap,
    this.onDirectionsTap,
  });

  /// 🔥 Vet-specific data normalization (خیلی مهم برای آینده)
  BusinessCardData _mapToBusinessData() {
  return BusinessCardData(
    id: data.id,
    name: data.name,
    city: data.city,
    district: data.district,
    address: data.address,

    // 🔥 FIXED IMAGE LOGIC
    logoUrl: (data.coverImageUrl != null && data.coverImageUrl!.isNotEmpty)
        ? data.coverImageUrl
        : data.logoUrl,

    distanceKm: data.distanceKm,

    specialties: data.specialties.isNotEmpty
        ? data.specialties
        : ['Veterinary'],

    services: data.services,

    phone: data.phone,
    whatsapp: data.whatsapp,

    rating: data.rating,
    reviewsCount: data.reviewsCount,

    workingHours: data.workingHours,
    description: data.description,

    instagram: data.instagram,
    website: data.website,

    isPartner: data.isPartner,
    is24h: data.is24h,
    isEmergency: data.isEmergency,

    type: BusinessType.vet,
  );
}

  @override
  Widget build(BuildContext context) {
    final businessData = _mapToBusinessData();

    return BusinessCard(
      data: businessData,

      onTap: onTap,

      // 📞 Call
      onCallTap: onCallTap,

      // 💬 WhatsApp
      onWhatsAppTap: onWhatsAppTap,

      // 🧭 Directions
      onDirectionsTap: onDirectionsTap,
    );
  }
}