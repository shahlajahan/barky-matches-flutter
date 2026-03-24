enum SubscriptionStatus {
  active,
  expired,
  canceled,
  gracePeriod,
  suspended;

  /// Convert Firestore string → enum
  static SubscriptionStatus fromString(String? value) {
    switch (value) {
      case 'expired':
        return SubscriptionStatus.expired;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'grace_period':
        return SubscriptionStatus.gracePeriod;
      case 'suspended':
        return SubscriptionStatus.suspended;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }

  /// Convert enum → Firestore string
  String toFirestore() {
    switch (this) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.canceled:
        return 'canceled';
      case SubscriptionStatus.gracePeriod:
        return 'grace_period';
      case SubscriptionStatus.suspended:
        return 'suspended';
    }
  }

  /// Only active unlocks paid features
  bool get isActive {
    return this == SubscriptionStatus.active;
  }

  /// Subscription no longer usable
  bool get isInactive {
    return this == SubscriptionStatus.expired ||
        this == SubscriptionStatus.canceled ||
        this == SubscriptionStatus.suspended;
  }

  /// Temporary state (payment problem)
  bool get isGracePeriod {
    return this == SubscriptionStatus.gracePeriod;
  }
}