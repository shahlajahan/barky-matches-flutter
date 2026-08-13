import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_reconciliation.dart';

void main() {
  test(
    'request identity remains stable until the logical booking completes',
    () {
      final identity = PetTaxiBookingRequestIdentity();
      final first = identity.value;
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(identity.value, first);

      identity.clear();
      expect(identity.value, isNot(first));
    },
  );

  test(
    'ambiguous callable errors are retryable but validation errors are not',
    () {
      expect(
        isPetTaxiAmbiguousOutcome(
          FirebaseFunctionsException(code: 'unknown', message: 'TLS'),
        ),
        isTrue,
      );
      expect(
        isPetTaxiAmbiguousOutcome(
          FirebaseFunctionsException(code: 'invalid-argument', message: 'bad'),
        ),
        isFalse,
      );
    },
  );

  test(
    'reconciliation retries with the same logical request and returns success',
    () async {
      final identity = PetTaxiBookingRequestIdentity();
      final requestId = identity.value;
      var attempts = 0;
      final result = await reconcilePetTaxiBooking(() async {
        expect(identity.value, requestId);
        attempts += 1;
        if (attempts == 1) {
          throw FirebaseFunctionsException(code: 'unknown', message: 'TLS');
        }
        return {'bookingId': 'booking-1'};
      }, delayForAttempt: (_) => Duration.zero);

      expect(result['bookingId'], 'booking-1');
      expect(attempts, 2);
      expect(identity.value, requestId);
    },
  );

  test(
    'definitive errors do not retry and exhausted ambiguity is bounded',
    () async {
      var validationAttempts = 0;
      await expectLater(
        reconcilePetTaxiBooking(() async {
          validationAttempts += 1;
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'not allowed',
          );
        }, delayForAttempt: (_) => Duration.zero),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(validationAttempts, 1);

      var ambiguousAttempts = 0;
      await expectLater(
        reconcilePetTaxiBooking(() async {
          ambiguousAttempts += 1;
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'offline',
          );
        }, delayForAttempt: (_) => Duration.zero),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(ambiguousAttempts, 3);
    },
  );
}
