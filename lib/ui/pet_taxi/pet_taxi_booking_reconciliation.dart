import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

class PetTaxiBookingRequestIdentity {
  String? _value;

  String get value => _value ??= Uuid().v4();

  bool get hasValue => _value != null;

  void clear() => _value = null;
}

bool isPetTaxiAmbiguousOutcome(Object error) {
  if (error is TimeoutException) return true;
  if (error is! FirebaseFunctionsException) return false;
  return const {
    'unknown',
    'unavailable',
    'deadline-exceeded',
  }.contains(error.code);
}

Future<T> reconcilePetTaxiBooking<T>(
  Future<T> Function() call, {
  int maxAttempts = 3,
  Duration Function(int attempt)? delayForAttempt,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await call();
    } catch (error) {
      lastError = error;
      if (!isPetTaxiAmbiguousOutcome(error) || attempt == maxAttempts - 1) {
        rethrow;
      }
      await Future<void>.delayed(
        delayForAttempt?.call(attempt) ??
            Duration(milliseconds: 500 * (attempt + 1)),
      );
    }
  }
  throw lastError ?? StateError('Booking reconciliation failed');
}
