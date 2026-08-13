import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';

void main() {
  test('classifies the backend Apple ownership-conflict responses only', () {
    expect(
      isAppleSubscriptionOwnershipConflict(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'This Apple purchase is linked to another account',
        ),
      ),
      isTrue,
    );
    expect(
      isAppleSubscriptionOwnershipConflict(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'This store purchase is already linked to another account',
        ),
      ),
      isTrue,
    );
  });

  test(
    'does not classify generic, network, or unrelated permission errors',
    () {
      expect(
        isAppleSubscriptionOwnershipConflict(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Mobile subscription verification failed',
          ),
        ),
        isFalse,
      );
      expect(
        isAppleSubscriptionOwnershipConflict(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Not authorized',
          ),
        ),
        isFalse,
      );
    },
  );
}
