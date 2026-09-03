import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_status.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';
import 'package:barky_matches_fixed/subscription/helpers/subscription_access.dart';

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

  // =====================================================================
  // Offline-cache timestamp round trip.
  //
  // `AppState._refreshSubscriptionHiveCache` serialises the subscription
  // through `cleanDeep`, which converts DateTime/Timestamp to an ISO-8601
  // String. Restoring that cache previously produced the exact reported
  // contradiction: plan=gold, status=active, yet isGold/canRegisterBusiness
  // false, because `expiresAt` parsed back as null.
  // =====================================================================
  group('timestamp parsing across storage representations', () {
    final future = DateTime.now().add(const Duration(days: 30));
    final past = DateTime.now().subtract(const Duration(days: 1));

    test('reproduces the reported false negative: ISO-8601 cached expiry', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        // Exactly what cleanDeep writes into Hive.
        'expiresAt': future.toIso8601String(),
        'source': 'admin_grant',
      });

      // The labels always survived the round trip — this is what the device
      // log showed.
      expect(subscription.plan, SubscriptionPlan.gold);
      expect(subscription.status, SubscriptionStatus.active);

      // These were false before the fix.
      expect(subscription.expiresAt, isNotNull);
      expect(subscription.hasValidPaidAccess, isTrue);
      expect(SubscriptionAccess(subscription).canRegisterBusiness, isTrue);
    });

    test('accepts a DateTime expiry', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': future,
      });
      expect(subscription.hasValidPaidAccess, isTrue);
    });

    test('accepts epoch milliseconds', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': future.millisecondsSinceEpoch,
      });
      expect(subscription.hasValidPaidAccess, isTrue);
    });

    test('an expired ISO-8601 expiry still fails closed', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'expiresAt': past.toIso8601String(),
      });

      expect(subscription.expiresAt, isNotNull);
      expect(subscription.hasValidPaidAccess, isFalse);
      expect(SubscriptionAccess(subscription).canRegisterBusiness, isFalse);
    });

    test('a missing expiry still fails closed — no expiry is invented', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
      });

      expect(subscription.expiresAt, isNull);
      expect(subscription.hasValidPaidAccess, isFalse);
      expect(SubscriptionAccess(subscription).canRegisterBusiness, isFalse);
    });

    test('malformed timestamps fail closed rather than throwing', () {
      for (final malformed in <dynamic>[
        '',
        '   ',
        'not-a-date',
        'yesterday',
        <String>['2026-01-01'],
        <String, dynamic>{'seconds': 123},
        true,
      ]) {
        final subscription = UserSubscription.fromMap({
          'plan': 'gold',
          'status': 'active',
          'expiresAt': malformed,
        });
        expect(subscription.expiresAt, isNull, reason: '$malformed');
        expect(subscription.hasValidPaidAccess, isFalse, reason: '$malformed');
      }
    });

    test('cancelled server state fails closed even with a future expiry', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'expired',
        'expiresAt': future.toIso8601String(),
      });

      expect(subscription.hasValidPaidAccess, isFalse);
      expect(SubscriptionAccess(subscription).canRegisterBusiness, isFalse);
    });

    test('Premium is not sufficient for business registration', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'premium',
        'status': 'active',
        'expiresAt': future.toIso8601String(),
      });

      expect(subscription.hasValidPaidAccess, isTrue);
      expect(SubscriptionAccess(subscription).canRegisterBusiness, isFalse);
    });

    test('admin_grant and app_store Gold are treated identically', () {
      for (final source in const ['admin_grant', 'app_store']) {
        final subscription = UserSubscription.fromMap({
          'plan': 'gold',
          'status': 'active',
          'expiresAt': future.toIso8601String(),
          'source': source,
        });
        expect(
          SubscriptionAccess(subscription).canRegisterBusiness,
          isTrue,
          reason: source,
        );
      }
    });

    test('startedAt and lastUpdatedAt survive the same round trip', () {
      final subscription = UserSubscription.fromMap({
        'plan': 'gold',
        'status': 'active',
        'startedAt': past.toIso8601String(),
        'expiresAt': future.toIso8601String(),
        'lastUpdatedAt': past.toIso8601String(),
      });

      expect(subscription.startedAt, isNotNull);
      expect(subscription.lastUpdatedAt, isNotNull);
    });
  });
}
