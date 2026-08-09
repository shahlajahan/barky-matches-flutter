import 'package:flutter/material.dart';

import '../../services/petshop_checkout_service.dart';
import '../../ui/petshop/checkout_session_presenter.dart';
import '../models/promotion_enums.dart';
import '../models/promotion_plan.dart';
import '../models/promotion_service_sector.dart';
import '../pages/promotion_performance_page.dart';
import '../services/promotion_checkout_service.dart';
import '../services/promotion_featured_deal_refresh_policy.dart';
import '../services/promotion_plan_service.dart';

/// Generic fixed-duration purchase sheet. Target-specific screens provide only
/// identity and presentation context; price and activation remain server-owned.
class PromotionPlanSheet extends StatefulWidget {
  const PromotionPlanSheet({
    super.key,
    required this.hostContext,
    required this.targetType,
    required this.targetId,
    required this.title,
    this.businessId,
    this.sector,
    this.planService,
  });

  final BuildContext hostContext;
  final PromotionTargetType targetType;
  final String targetId;
  final String title;
  final String? businessId;
  final PromotionServiceSector? sector;
  final PromotionPlanService? planService;

  static Future<void> show(
    BuildContext context, {
    required PromotionTargetType targetType,
    required String targetId,
    required String title,
    String? businessId,
    PromotionServiceSector? sector,
    PromotionPlanService? planService,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PromotionPlanSheet(
      hostContext: context,
      targetType: targetType,
      targetId: targetId,
      title: title,
      businessId: businessId,
      sector: sector,
      planService: planService,
    ),
  );

  @override
  State<PromotionPlanSheet> createState() => _PromotionPlanSheetState();
}

class _PromotionPlanSheetState extends State<PromotionPlanSheet> {
  late final Future<List<PromotionPlan>> _plansFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plansFuture = (widget.planService ?? PromotionPlanService()).readPlans(
      widget.targetType,
    );
  }

  String _durationLabel(int hours) {
    switch (hours) {
      case 24:
        return '24 hours';
      case 72:
        return '3 days';
      case 168:
        return '7 days';
      default:
        return '$hours hours';
    }
  }

  Future<void> _start(PromotionPlan plan) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final checkout = await PromotionCheckoutService().createCheckout(
        targetType: widget.targetType.value,
        targetId: widget.targetId,
        planId: plan.planId,
        businessId: widget.businessId,
        sector: widget.sector?.value,
        idempotencyKey:
            '${widget.targetType.value.toLowerCase()}-${widget.targetId}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      final campaignId = checkout['campaignId']?.toString();
      if (campaignId == null || campaignId.isEmpty) {
        throw StateError('Promotion checkout did not return a campaign ID');
      }
      Navigator.of(context).pop();
      if (!widget.hostContext.mounted) return;
      await presentCheckoutSession(
        context: widget.hostContext,
        session: CheckoutSessionResult.fromJson({
          ...checkout,
          'orderId': campaignId,
        }),
        orderId: campaignId,
        successUrlPrefix: 'https://app.petsupo.com/promotion-payment-return',
        cancelUrlPrefix: 'https://app.petsupo.com/promotion-payment-return',
      );
      if (!widget.hostContext.mounted) return;
      final status = await PromotionCheckoutService().waitForPaymentStatus(
        campaignId,
      );
      if (!widget.hostContext.mounted) return;
      final active =
          status['campaignStatus']?.toString().toLowerCase() == 'active';
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Promotion active.' : 'Payment is still being verified.',
          ),
        ),
      );
      if (active && widget.hostContext.mounted) {
        PromotionFeaturedDealRefreshPolicy.invalidate();
        await Navigator.of(widget.hostContext).push(
          MaterialPageRoute<void>(
            builder: (_) => PromotionPerformancePage(
              campaignId: campaignId,
              targetLabel: widget.title,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        widget.hostContext,
      ).showSnackBar(SnackBar(content: Text('Promotion failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<PromotionPlan>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final plans = snapshot.data ?? const <PromotionPlan>[];
          if (snapshot.hasError || plans.isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('Promotion plans are unavailable.')),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Choose a fixed-duration promotion plan.'),
              const SizedBox(height: 14),
              ...plans.map(
                (plan) => ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.rocket_launch),
                  title: Text(_durationLabel(plan.durationHours)),
                  subtitle: Text('Server plan ${plan.planId}'),
                  trailing: Text(
                    '${plan.price.toStringAsFixed(0)} ${plan.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => _start(plan),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
