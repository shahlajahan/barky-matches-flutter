enum SubscriptionPlan {
  normal,
  premium,
  gold;

  /// Convert Firestore string → enum
  static SubscriptionPlan fromString(String? value) {
    switch (value) {
      case 'premium':
        return SubscriptionPlan.premium;
      case 'gold':
        return SubscriptionPlan.gold;
      case 'normal':
      default:
        return SubscriptionPlan.normal;
    }
  }

  /// Convert enum → Firestore string
  String toFirestore() {
    switch (this) {
      case SubscriptionPlan.normal:
        return 'normal';
      case SubscriptionPlan.premium:
        return 'premium';
      case SubscriptionPlan.gold:
        return 'gold';
    }
  }

  /// Is paid plan
  bool get isPaid {
    return this == SubscriptionPlan.premium ||
        this == SubscriptionPlan.gold;
  }

  /// Is premium
  bool get isPremium {
    return this == SubscriptionPlan.premium;
  }

  /// Is gold
  bool get isGold {
    return this == SubscriptionPlan.gold;
  }
}