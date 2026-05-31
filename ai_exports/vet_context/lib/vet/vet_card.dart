import 'package:flutter/material.dart';

import '../business/business_card.dart';
import '../business/business_card_data.dart';
import 'vet_card_data.dart';

class VetCard extends StatelessWidget {
  final VetCardData data;

  final VoidCallback? onTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onDirectionsTap;
  final VoidCallback? onMessageTap;

  const VetCard({
    super.key,
    required this.data,
    this.onTap,
    this.onCallTap,
    this.onWhatsAppTap,
    this.onDirectionsTap,
    this.onMessageTap,
  });

  /// 🔥 Vet-specific data normalization
  BusinessCardData _mapToBusinessData() {
    return BusinessCardData(
      id: data.id,
      name: data.name,
      city: data.city,
      district: data.district,
      address: data.address,

      data: data.toMap(),

      // 🔥 FIXED IMAGE LOGIC
      logoUrl: (data.coverImageUrl != null && data.coverImageUrl!.isNotEmpty)
          ? data.coverImageUrl
          : data.logoUrl,

      distanceKm: data.distanceKm,

      specialties: data.specialties.isNotEmpty
          ? data.specialties
          : ['Veterinary'],

      phone: data.phone,
      whatsapp: data.whatsapp,

      rating: data.rating,
      reviewsCount: data.reviewsCount,

      // 🔥 NEW WORKING HOURS STRUCTURE
      workingHours: _normalizedWorkingHours(),

      description: data.description,

      instagram: data.instagram,
      website: data.website,

      isPartner: data.isPartner,
      is24h: data.is24h,
      isEmergency: data.isEmergency,

      type: BusinessType.vet,
    );
  }

  /// 🔥 NORMALIZE HOURS
  /// Supports:
  /// - new workingHoursMap
  /// - old string structure
  /// - legacy hours field
  Map<String, dynamic>? _normalizedWorkingHours() {
    final hours = data.workingHours;

    if (hours == null || hours.isEmpty) {
      return null;
    }

    final normalized = <String, dynamic>{};

    hours.forEach((key, value) {
      // 🔥 NEW STRUCTURE
      if (value is Map<String, dynamic>) {
        normalized[key] = value;
      }
      // 🔥 OLD STRING
      else if (value is String) {
        normalized[key] = {
          'open': value.toLowerCase() != 'closed',
          'hours': value,
        };
      }
    });

    // 🔥 LEGACY FALLBACK
    if (normalized.isEmpty && hours['hours'] is String) {
      normalized['monday'] = {'open': true, 'hours': hours['hours']};
    }

    return normalized;
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

      // 💬 Internal message
      onMessageTap: onMessageTap,

      // 🧭 Directions
      onDirectionsTap: onDirectionsTap,
    );
  }
}
