import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_campaign.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_enums.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_plan.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_target.dart';

void main() {
  final createdAt = Timestamp.fromDate(DateTime.utc(2026, 8, 8, 10));

  PromotionPlan plan({
    PromotionTargetType targetType = PromotionTargetType.product,
  }) {
    return PromotionPlan(
      planId: 'product_7d_v1',
      targetType: targetType,
      pricingModel: PromotionPricingModel.fixedDuration,
      durationHours: 168,
      price: 169,
      currency: 'TRY',
      rankingLift: 20,
      enabled: true,
      pricingVersion: 1,
      displayOrder: 3,
      maxConcurrentPerOwner: 3,
      maxConcurrentPerBusiness: 5,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  PromotionTarget target() => const PromotionTarget(
    targetType: PromotionTargetType.product,
    targetId: 'product-1',
    ownerUid: 'owner-1',
    businessId: 'business-1',
    sector: 'pet_shop',
  );

  test('PromotionTarget round-trips all target identity fields', () {
    final restored = PromotionTarget.fromJson(target().toJson());

    expect(restored.targetType, PromotionTargetType.product);
    expect(restored.targetId, 'product-1');
    expect(restored.ownerUid, 'owner-1');
    expect(restored.businessId, 'business-1');
    expect(restored.sector, 'pet_shop');
  });

  test(
    'PromotionPlan parses versioned server terms without UI pricing constants',
    () {
      final original = plan();
      final restored = PromotionPlan.fromJson(
        original.planId,
        original.toJson(),
      );

      expect(restored.targetType, PromotionTargetType.product);
      expect(restored.pricingModel, PromotionPricingModel.fixedDuration);
      expect(restored.durationHours, 168);
      expect(restored.price, 169);
      expect(restored.currency, 'TRY');
      expect(restored.pricingVersion, 1);
      expect(restored.maxConcurrentPerBusiness, 5);
    },
  );

  test('PromotionCampaign snapshots plan commercial terms', () {
    final campaign = PromotionCampaign.draftFromPlan(
      campaignId: 'campaign-1',
      target: target(),
      plan: plan(),
      createdAt: createdAt,
    );

    expect(campaign.status, PromotionCampaignStatus.draft);
    expect(campaign.price, 169);
    expect(campaign.durationHours, 168);
    expect(campaign.pricingVersion, 1);
    expect(campaign.targetId, 'product-1');
  });

  test('PromotionCampaign rejects a plan for a different target type', () {
    expect(
      () => PromotionCampaign.draftFromPlan(
        campaignId: 'campaign-1',
        target: target(),
        plan: plan(targetType: PromotionTargetType.service),
        createdAt: createdAt,
      ),
      throwsFormatException,
    );
  });

  test('campaign transitions reject arbitrary activation and reopening', () {
    final campaign = PromotionCampaign.draftFromPlan(
      campaignId: 'campaign-1',
      target: target(),
      plan: plan(),
      createdAt: createdAt,
    );
    final pending = campaign.transitionTo(
      PromotionCampaignStatus.pendingPayment,
    );
    final processing = pending.transitionTo(
      PromotionCampaignStatus.paymentProcessing,
    );
    final active = processing.transitionTo(PromotionCampaignStatus.active);
    final expired = active.transitionTo(PromotionCampaignStatus.expired);

    expect(expired.status, PromotionCampaignStatus.expired);
    expect(
      () => campaign.transitionTo(PromotionCampaignStatus.active),
      throwsStateError,
    );
    expect(
      () => expired.transitionTo(PromotionCampaignStatus.active),
      throwsStateError,
    );
  });

  test('expiry eligibility is false at and after expiry', () {
    final base = PromotionCampaign.draftFromPlan(
      campaignId: 'campaign-1',
      target: target(),
      plan: plan(),
      createdAt: createdAt,
    );
    final active = base
        .transitionTo(PromotionCampaignStatus.pendingPayment)
        .transitionTo(PromotionCampaignStatus.paymentProcessing)
        .transitionTo(PromotionCampaignStatus.active);

    final activeWithWindow = PromotionCampaign.fromJson(active.campaignId, {
      ...active.toJson(),
      'startsAt': createdAt,
      'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 8, 8, 11)),
    });

    expect(
      activeWithWindow.isEligibleAt(DateTime.utc(2026, 8, 8, 10, 30)),
      isTrue,
    );
    expect(
      activeWithWindow.isEligibleAt(DateTime.utc(2026, 8, 8, 11)),
      isFalse,
    );
  });

  test(
    'future pricing models parse as extension values but are not V1 plan terms',
    () {
      expect(
        PromotionPricingModel.fromValue('CPC_BUDGET'),
        PromotionPricingModel.cpcBudget,
      );
      expect(PromotionPricingModel.fromValue('CPA'), PromotionPricingModel.cpa);
    },
  );
}
