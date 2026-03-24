import '../business/business_card.dart';
import '../business/business_card_data.dart';
import 'vet_card_data.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return BusinessCard(
      data: data,
      onTap: onTap,
      onCallTap: onCallTap,
      onWhatsAppTap: onWhatsAppTap,
      onDirectionsTap: onDirectionsTap,
    );
  }
}