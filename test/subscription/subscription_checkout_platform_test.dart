import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/subscription/subscription_checkout_platform.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_return_page.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_service.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';

void main() {
  test('formats authoritative TRY Web catalog prices with lira symbol', () {
    const premium = WebSubscriptionPlanPresentation(
      planId: 'premium',
      amount: 199,
      currency: 'TRY',
      termDays: 30,
    );
    const gold = WebSubscriptionPlanPresentation(
      planId: 'gold',
      amount: 499,
      currency: 'TRY',
      termDays: 30,
    );

    expect(premium.formattedPrice, '₺199');
    expect(gold.formattedPrice, '₺499');
  });

  test('parses the deployed authoritative catalog schema', () {
    final catalog = WebSubscriptionService.parseWebSubscriptionCatalog({
      'plans': {
        'premium': {'amount': 199, 'currency': 'TRY', 'durationDays': 30},
        'gold': {'amount': '499.00', 'currency': 'TRY', 'durationDays': 30},
      },
    });

    expect(catalog['premium']?.formattedPrice, '₺199');
    expect(catalog['gold']?.formattedPrice, '₺499');
    expect(catalog.values.every((plan) => plan.termDays == 30), isTrue);
  });

  test('Web content remains readable and constrained at responsive widths', () {
    expect(
      upgradeContentWidth(viewportWidth: 1920, isWeb: true),
      webUpgradeContentMaxWidth,
    );
    expect(
      upgradeContentWidth(viewportWidth: 1440, isWeb: true),
      webUpgradeContentMaxWidth,
    );
    expect(upgradeContentWidth(viewportWidth: 768, isWeb: true), 768);
    expect(upgradeContentWidth(viewportWidth: 390, isWeb: true), 390);
    expect(upgradeContentWidth(viewportWidth: 1440, isWeb: false), 1440);
  });

  test('Web selects İş Bank and never initializes native IAP', () {
    expect(
      subscriptionCheckoutPlatform(
        isWeb: true,
        targetPlatform: TargetPlatform.iOS,
      ),
      SubscriptionCheckoutPlatform.webIsbank,
    );
    expect(
      shouldInitializeNativeSubscriptionIap(
        isWeb: true,
        targetPlatform: TargetPlatform.iOS,
      ),
      isFalse,
    );
  });

  test('iOS and Android retain their native store paths', () {
    expect(
      subscriptionCheckoutPlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      SubscriptionCheckoutPlatform.appleIap,
    );
    expect(
      subscriptionCheckoutPlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      SubscriptionCheckoutPlatform.googlePlay,
    );
  });

  test('mobile IAP is enabled after server store verification is configured', () {
    expect(IapService.mobileIapEnabled, isTrue);
  });

  test('mobile upgrade purchase and restore controls are enabled', () {
    expect(mobileIapPurchaseControlsEnabled(), isTrue);
  });

  test('return state trusts only verified backend success', () {
    const pending = WebSubscriptionPaymentStatus(
      status: 'pending',
      verified: false,
    );
    const paid = WebSubscriptionPaymentStatus(status: 'paid', verified: true);
    const failed = WebSubscriptionPaymentStatus(
      status: 'failed',
      verified: false,
    );

    expect(
      webSubscriptionReturnState(
        returnPath: '/isbank/3d-success',
        status: pending,
      ),
      WebSubscriptionReturnState.pending,
    );
    expect(
      webSubscriptionReturnState(
        returnPath: '/isbank/3d-success',
        status: paid,
      ),
      WebSubscriptionReturnState.success,
    );
    expect(
      webSubscriptionReturnState(
        returnPath: '/isbank/3d-success',
        status: failed,
      ),
      WebSubscriptionReturnState.failed,
    );
    expect(
      webSubscriptionReturnState(
        returnPath: '/isbank/3d-fail',
        status: pending,
      ),
      WebSubscriptionReturnState.cancelled,
    );
  });
}
