import 'package:flutter/material.dart';

import '../models/promotion_enums.dart';
import '../models/promotion_service_sector.dart';
import '../services/promotion_plan_service.dart';
import 'promotion_plan_sheet.dart';

/// The single service-card entry point for the M7 Promotion flow.
///
/// Domain eligibility remains server-authoritative. The UI only preserves the
/// existing M7 visibility rule: enabled sector plus an active service.
class ServicePromotionAction extends StatelessWidget {
  const ServicePromotionAction({
    super.key,
    required this.businessId,
    required this.serviceId,
    required this.serviceTitle,
    required this.sector,
    required this.isActive,
    this.planService,
  });

  final String businessId;
  final String serviceId;
  final String serviceTitle;
  final PromotionServiceSector sector;
  final bool isActive;
  final PromotionPlanService? planService;

  static bool isEligible({
    required PromotionServiceSector sector,
    required Object? isActive,
  }) => sector.m7Enabled && isActive == true;

  static String canonicalTargetId({
    required PromotionServiceSector sector,
    required String businessId,
    required String serviceId,
  }) => PromotionServiceTargetId(
    sector: sector,
    businessId: businessId,
    serviceId: serviceId,
  ).value;

  @override
  Widget build(BuildContext context) {
    if (!isEligible(sector: sector, isActive: isActive)) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.rocket_launch),
      label: const Text('Boost service'),
      onPressed: () => PromotionPlanSheet.show(
        context,
        targetType: PromotionTargetType.service,
        targetId: canonicalTargetId(
          sector: sector,
          businessId: businessId,
          serviceId: serviceId,
        ),
        businessId: businessId,
        sector: sector,
        planService: planService,
        title: 'Boost ${serviceTitle.isEmpty ? 'service' : serviceTitle}',
      ),
    );
  }
}
