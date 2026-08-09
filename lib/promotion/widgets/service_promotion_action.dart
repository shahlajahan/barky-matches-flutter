import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/promotion_enums.dart';
import '../models/promotion_campaign_stats.dart';
import '../models/promotion_service_sector.dart';
import '../pages/promotion_performance_page.dart';
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
    this.activeCampaignId,
    this.loadPerformanceStats,
    this.planService,
  });

  final String businessId;
  final String serviceId;
  final String serviceTitle;
  final PromotionServiceSector sector;
  final bool isActive;
  final String? activeCampaignId;
  final Future<PromotionCampaignStats> Function(String campaignId)?
  loadPerformanceStats;
  final PromotionPlanService? planService;

  static Map<String, String> activeCampaignIdsForProjections({
    required Iterable<Map<String, dynamic>> projections,
    required String businessId,
    required PromotionServiceSector sector,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final result = <String, String>{};
    for (final projection in projections) {
      if (projection['targetType']?.toString().toUpperCase() != 'SERVICE' ||
          projection['featuredDealEligible'] != true) {
        continue;
      }
      PromotionServiceTargetId? target;
      try {
        target = PromotionServiceTargetId.parse(
          projection['targetId']?.toString() ?? '',
        );
      } on FormatException {
        continue;
      }
      if (target == null ||
          target.businessId != businessId ||
          target.sector != sector) {
        continue;
      }
      DateTime? asDate(Object? value) {
        if (value is DateTime) return value;
        if (value is Timestamp) return value.toDate();
        return DateTime.tryParse(value?.toString() ?? '');
      }

      final startsAt = asDate(projection['startsAt']);
      final expiresAt = asDate(projection['expiresAt']);
      final campaignId = projection['campaignId']?.toString();
      if (campaignId == null ||
          campaignId.isEmpty ||
          startsAt == null ||
          expiresAt == null) {
        continue;
      }
      if (!reference.isBefore(startsAt) && reference.isBefore(expiresAt)) {
        result[target.value] ??= campaignId;
      }
    }
    return result;
  }

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

    if (activeCampaignId != null && activeCampaignId!.isNotEmpty) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.analytics_outlined),
        label: const Text('View promotion performance'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PromotionPerformancePage(
              campaignId: activeCampaignId!,
              targetLabel: serviceTitle,
              loadStats: loadPerformanceStats,
            ),
          ),
        ),
      );
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
