import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/subscription/helpers/subscription_access.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_source.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_status.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';

UserSubscription paid({
  DateTime? expiresAt,
  SubscriptionPlan plan = SubscriptionPlan.premium,
}) {
  return UserSubscription(
    plan: plan,
    status: SubscriptionStatus.active,
    expiresAt: expiresAt,
    autoRenew: true,
    source: SubscriptionSource.appStore,
  );
}

void main() {
  test('active paid access requires a future expiry', () {
    expect(
      SubscriptionAccess(
        paid(expiresAt: DateTime.now().add(const Duration(hours: 1))),
      ).canUsePremiumChat,
      isTrue,
    );
    expect(
      SubscriptionAccess(
        paid(expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
      ).canUsePremiumChat,
      isFalse,
    );
  });

  test('legacy paid cache without expiry fails closed', () {
    expect(SubscriptionAccess(paid()).canUsePremiumChat, isFalse);
  });

  test('Gold access also requires temporal validity', () {
    expect(
      SubscriptionAccess(
        paid(
          plan: SubscriptionPlan.gold,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ).canRegisterBusiness,
      isTrue,
    );
    expect(
      SubscriptionAccess(
        paid(
          plan: SubscriptionPlan.gold,
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      ).canRegisterBusiness,
      isFalse,
    );
    expect(
      SubscriptionAccess(
        UserSubscription(
          plan: SubscriptionPlan.gold,
          status: SubscriptionStatus.canceled,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          autoRenew: false,
          source: SubscriptionSource.appStore,
        ),
      ).canRegisterBusiness,
      isFalse,
    );
  });
}
