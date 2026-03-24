enum SubscriptionSource {
  free,
  appStore,
  playStore,
  admin;

  /// Convert Firestore string → enum
  static SubscriptionSource fromString(String? value) {
    switch (value) {
      case 'app_store':
        return SubscriptionSource.appStore;
      case 'play_store':
        return SubscriptionSource.playStore;
      case 'admin':
        return SubscriptionSource.admin;
      case 'free':
      default:
        return SubscriptionSource.free;
    }
  }

  /// Convert enum → Firestore string
  String toFirestore() {
    switch (this) {
      case SubscriptionSource.free:
        return 'free';
      case SubscriptionSource.appStore:
        return 'app_store';
      case SubscriptionSource.playStore:
        return 'play_store';
      case SubscriptionSource.admin:
        return 'admin';
    }
  }

  /// Is subscription coming from store
  bool get isStorePurchase {
    return this == SubscriptionSource.appStore ||
        this == SubscriptionSource.playStore;
  }

  /// Is manually granted by admin
  bool get isAdminGranted {
    return this == SubscriptionSource.admin;
  }

  /// Is free plan
  bool get isFree {
    return this == SubscriptionSource.free;
  }
}