/// Stable wire values for the central Promotion Engine.
enum PromotionTargetType {
  pet('PET'),
  product('PRODUCT'),
  service('SERVICE'),
  business('BUSINESS');

  const PromotionTargetType(this.value);

  final String value;

  static PromotionTargetType fromValue(Object? value) {
    final normalized = value?.toString().trim().toUpperCase();
    return values.firstWhere(
      (type) => type.value == normalized,
      orElse: () =>
          throw FormatException('Unknown promotion target type: $value'),
    );
  }
}

enum PromotionPricingModel {
  fixedDuration('FIXED_DURATION'),
  cpcBudget('CPC_BUDGET'),
  cpa('CPA');

  const PromotionPricingModel(this.value);

  final String value;

  static PromotionPricingModel fromValue(Object? value) {
    final normalized = value?.toString().trim().toUpperCase();
    return values.firstWhere(
      (model) => model.value == normalized,
      orElse: () =>
          throw FormatException('Unknown promotion pricing model: $value'),
    );
  }
}

enum PromotionCampaignStatus {
  draft('draft'),
  pendingPayment('pending_payment'),
  paymentProcessing('payment_processing'),
  active('active'),
  expired('expired'),
  cancelled('cancelled'),
  failed('failed'),
  refunded('refunded');

  const PromotionCampaignStatus(this.value);

  final String value;

  static PromotionCampaignStatus fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return values.firstWhere(
      (status) => status.value == normalized,
      orElse: () =>
          throw FormatException('Unknown promotion campaign status: $value'),
    );
  }
}

const Map<PromotionCampaignStatus, Set<PromotionCampaignStatus>>
allowedPromotionCampaignTransitions = {
  PromotionCampaignStatus.draft: {
    PromotionCampaignStatus.pendingPayment,
    PromotionCampaignStatus.cancelled,
    PromotionCampaignStatus.failed,
  },
  PromotionCampaignStatus.pendingPayment: {
    PromotionCampaignStatus.paymentProcessing,
    PromotionCampaignStatus.cancelled,
    PromotionCampaignStatus.failed,
  },
  PromotionCampaignStatus.paymentProcessing: {
    PromotionCampaignStatus.active,
    PromotionCampaignStatus.cancelled,
    PromotionCampaignStatus.failed,
  },
  PromotionCampaignStatus.active: {
    PromotionCampaignStatus.expired,
    PromotionCampaignStatus.cancelled,
    PromotionCampaignStatus.refunded,
  },
  PromotionCampaignStatus.expired: {},
  PromotionCampaignStatus.cancelled: {},
  PromotionCampaignStatus.failed: {},
  PromotionCampaignStatus.refunded: {},
};

bool isAllowedPromotionCampaignTransition(
  PromotionCampaignStatus from,
  PromotionCampaignStatus to,
) {
  return allowedPromotionCampaignTransitions[from]?.contains(to) ?? false;
}

/// A local eligibility predicate for readers and tests.
///
/// The authoritative ranking implementation must use trusted server time and
/// campaign/projection data. This helper intentionally accepts [now] so it is
/// deterministic and cannot silently use device time in production ranking.
bool isPromotionEligibleAt({
  required PromotionCampaignStatus status,
  required DateTime now,
  required DateTime? startsAt,
  required DateTime? expiresAt,
}) {
  if (status != PromotionCampaignStatus.active ||
      startsAt == null ||
      expiresAt == null) {
    return false;
  }
  return !now.isBefore(startsAt) && now.isBefore(expiresAt);
}
