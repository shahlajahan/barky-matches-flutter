import 'package:flutter/foundation.dart';

enum SubscriptionCheckoutPlatform { webIsbank, appleIap, googlePlay }

SubscriptionCheckoutPlatform subscriptionCheckoutPlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return SubscriptionCheckoutPlatform.webIsbank;
  if (targetPlatform == TargetPlatform.iOS) {
    return SubscriptionCheckoutPlatform.appleIap;
  }
  return SubscriptionCheckoutPlatform.googlePlay;
}

bool shouldInitializeNativeSubscriptionIap({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  return subscriptionCheckoutPlatform(
        isWeb: isWeb,
        targetPlatform: targetPlatform,
      ) !=
      SubscriptionCheckoutPlatform.webIsbank;
}
