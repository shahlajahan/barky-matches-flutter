import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

import 'pet_hotel_details_overlay.dart';

class PetHotelDetailsPage extends StatelessWidget {
  final BusinessCardData data;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;
  final ValueChanged<Map<String, dynamic>>? onOpenBooking;

  const PetHotelDetailsPage({
    super.key,
    required this.data,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PetHotelDetailsOverlay(
        data: data,
        onClose: () => Navigator.maybePop(context),
        onCall: onCall,
        onWhatsApp: onWhatsApp,
        onDirections: onDirections,
        onOpenBooking: onOpenBooking,
      ),
    );
  }
}
