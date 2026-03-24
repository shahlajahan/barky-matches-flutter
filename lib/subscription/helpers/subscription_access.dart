import '../models/user_subscription.dart';
import '../models/subscription_plan.dart';
import '../models/subscription_status.dart';

class SubscriptionAccess {
  final UserSubscription subscription;

  const SubscriptionAccess(this.subscription);

  /// Only active subscriptions unlock paid features
  bool get _isActive {
    return subscription.status == SubscriptionStatus.active;
  }

  /// Premium OR Gold
  bool get _isPremiumOrGold {
    return subscription.plan == SubscriptionPlan.premium ||
        subscription.plan == SubscriptionPlan.gold;
  }

  /// GOLD ONLY
  bool get _isGold {
    return subscription.plan == SubscriptionPlan.gold;
  }

  // ------------------------------------------
  // Discovery Features
  // ------------------------------------------

  bool get canUseAdvancedFilters {
    return _isActive && _isPremiumOrGold;
  }

  bool get canBoostVisibility {
    return _isActive && _isPremiumOrGold;
  }

  bool get canSeeProfileInsights {
    return _isActive && _isPremiumOrGold;
  }

  // ------------------------------------------
  // Interaction Features
  // ------------------------------------------

  bool get canUsePremiumChat {
    return _isActive && _isPremiumOrGold;
  }

  bool get canUseAdvancedFavorites {
    return _isActive && _isPremiumOrGold;
  }

  bool get canCreateUnlimitedPlaydateRequests {
    return _isActive && _isPremiumOrGold;
  }

  bool get canAccessPrioritySupport {
    return _isActive && _isGold;
  }

  // ------------------------------------------
  // Business Features
  // ------------------------------------------

  /// 🔐 MOST IMPORTANT RULE
  /// Only GOLD users with ACTIVE subscription
  bool get canRegisterBusiness {
    return _isActive && _isGold;
  }

  bool get canAccessBusinessDashboard {
    return _isActive && _isGold;
  }

  bool get canPublishBusinessProfile {
    return _isActive && _isGold;
  }

  bool get canViewBusinessAnalytics {
    return _isActive && _isGold;
  }

  bool get canUseFeaturedBusinessPlacement {
    return _isActive && _isGold;
  }
}