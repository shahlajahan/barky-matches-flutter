import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_status.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';

void main() {
  test('parses active Gold from canonical Firestore data', () {
    final subscription = UserSubscription.fromMap({
      'plan': 'gold',
      'status': 'active',
    });

    expect(subscription.plan, SubscriptionPlan.gold);
    expect(subscription.status, SubscriptionStatus.active);
    expect(subscription.isGold, isTrue);
  });

  test('parses active Premium from canonical Firestore data', () {
    final subscription = UserSubscription.fromMap({
      'plan': 'premium',
      'status': 'active',
    });

    expect(subscription.plan, SubscriptionPlan.premium);
    expect(subscription.status, SubscriptionStatus.active);
  });

  test(
    'normalizes legacy casing and whitespace without changing plan meaning',
    () {
      expect(SubscriptionPlan.fromString(' Gold '), SubscriptionPlan.gold);
    },
  );

  test('missing subscription remains normal', () {
    expect(UserSubscription.fromMap(null).plan, SubscriptionPlan.normal);
  });

  test('expired and cancelled subscriptions retain plan but are inactive', () {
    for (final status in ['expired', 'cancelled']) {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': status,
      });
      expect(subscription.plan, SubscriptionPlan.gold);
      expect(subscription.isActive, isFalse);
    }
  });

  test('maps expired nested mobile status instead of defaulting to active', () {
    final subscription = UserSubscription.fromMap({
      'plan': 'normal',
      'status': 'active',
      'source': 'free',
      'mobile': {'plan': 'gold', 'status': 'expired', 'source': 'app_store'},
    });

    expect(subscription.plan, SubscriptionPlan.normal);
    expect(subscription.status, SubscriptionStatus.expired);
    expect(subscription.isActive, isFalse);
  });

  test(
    'maps active nested mobile Gold when effective top-level plan is normal',
    () {
      final subscription = UserSubscription.fromMap({
        'plan': 'normal',
        'status': 'active',
        'source': 'free',
        'mobile': {'plan': 'gold', 'status': 'active', 'source': 'app_store'},
      });

      expect(subscription.plan, SubscriptionPlan.gold);
      expect(subscription.status, SubscriptionStatus.active);
    },
  );
}
