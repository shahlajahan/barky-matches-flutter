import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../business_card_data.dart';

class AdoptionOverlayContent extends StatelessWidget {
  final BusinessCardData data;

  final bool showInfo;
  final bool showServices;
  final bool showAction;

  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback onClose;

  const AdoptionOverlayContent({
    super.key,
    required this.data,
    required this.showInfo,
    required this.showServices,
    required this.showAction,
    this.onCall,
    this.onWhatsApp,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      "Adoption Center (TEMP)",
      style: AppTheme.caption(color: Colors.white),
    );
  }
}