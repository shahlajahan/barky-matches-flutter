import 'package:barky_matches_fixed/services/appointment_notification_contract.dart';
import 'package:barky_matches_fixed/services/appointment_notification_navigation_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown non-appointment payload is not guarded', () async {
    var resolverCalls = 0;

    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {'type': 'chat_message', 'chatId': 'chat-1'},
      resolveAvailability: (_) async {
        resolverCalls += 1;
        return AppointmentNotificationAvailability.available;
      },
    );

    expect(decision, AppointmentNotificationNavigationDecision.notAppointment);
    expect(resolverCalls, 0);
  });

  test('malformed appointment payload fails closed without lookup', () async {
    var resolverCalls = 0;

    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {'type': 'vet_appointment_response'},
      resolveAvailability: (_) async {
        resolverCalls += 1;
        return AppointmentNotificationAvailability.available;
      },
    );

    expect(
      decision,
      AppointmentNotificationNavigationDecision.missingOrMalformed,
    );
    expect(resolverCalls, 0);
  });

  test(
    'available source allows appointment routing for every family',
    () async {
      const payloads = [
        {'type': 'vet_appointment_response', 'appointmentId': 'vet-1'},
        {'type': 'groomy_appointment_response', 'appointmentId': 'groomy-1'},
        {'type': 'hotel_booking_response', 'bookingId': 'hotel-1'},
        {'type': 'pet_taxi_status_update', 'bookingId': 'taxi-1'},
      ];

      for (final payload in payloads) {
        final decision = await AppointmentNotificationNavigationGuard.evaluate(
          payload,
          resolveAvailability: (_) async =>
              AppointmentNotificationAvailability.available,
        );

        expect(
          decision,
          AppointmentNotificationNavigationDecision.available,
          reason: payload.toString(),
        );
      }
    },
  );

  test('confirmed missing source blocks appointment routing', () async {
    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {'type': 'hotel_booking_response', 'bookingId': 'hotel-1'},
      resolveAvailability: (_) async =>
          AppointmentNotificationAvailability.missing,
    );

    expect(
      decision,
      AppointmentNotificationNavigationDecision.missingOrMalformed,
    );
  });

  test('transient lookup failure does not claim missing', () async {
    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {'type': 'pet_taxi_status_update', 'bookingId': 'taxi-1'},
      resolveAvailability: (_) async =>
          AppointmentNotificationAvailability.unknown,
    );

    expect(
      decision,
      AppointmentNotificationNavigationDecision.lookupFailedOrUnresolved,
    );
  });

  test('lookup exception is unresolved, not missing', () async {
    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {
        'type': 'groomy_appointment_response',
        'appointmentId': 'groomy-1',
      },
      resolveAvailability: (_) async => throw StateError('network unavailable'),
    );

    expect(
      decision,
      AppointmentNotificationNavigationDecision.lookupFailedOrUnresolved,
    );
  });

  test('generic appointmentCollection payload is supported', () async {
    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      const {
        'type': 'appointment_paid',
        'appointmentCollection': 'groomy_appointments',
        'appointmentId': 'groomy-1',
      },
      resolveAvailability: (_) async =>
          AppointmentNotificationAvailability.available,
    );

    expect(decision, AppointmentNotificationNavigationDecision.available);
  });

  test(
    'unknown appointmentCollection is rejected from appointment guard',
    () async {
      final decision = await AppointmentNotificationNavigationGuard.evaluate(
        const {
          'type': 'appointment_paid',
          'appointmentCollection': 'unknown_collection',
          'appointmentId': 'appointment-1',
        },
        resolveAvailability: (_) async =>
            AppointmentNotificationAvailability.available,
      );

      expect(
        decision,
        AppointmentNotificationNavigationDecision.missingOrMalformed,
      );
    },
  );
}
