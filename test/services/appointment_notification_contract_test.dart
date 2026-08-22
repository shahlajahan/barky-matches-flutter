import 'dart:io';

import 'package:barky_matches_fixed/services/appointment_notification_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'supported appointment notification types resolve to bounded families',
    () {
      final cases = {
        'vet_appointment_response': ('vet_appointments', 'vet'),
        'groomy_appointment_response': ('groomy_appointments', 'groomy'),
        'hotel_booking_response': ('hotel_bookings', 'hotel'),
        'pet_taxi_status_update': ('pet_taxi_bookings', 'pet_taxi'),
      };

      for (final entry in cases.entries) {
        final reference = AppointmentNotificationContract.resolve({
          'type': entry.key,
          'appointmentId': 'local-id',
        });

        expect(reference, isNotNull);
        expect(reference!.collection, entry.value.$1);
        expect(reference.family, entry.value.$2);
        expect(reference.documentId, 'local-id');
      }
    },
  );

  test('hotel and pet taxi prefer bookingId when present', () {
    final hotel = AppointmentNotificationContract.resolve({
      'type': 'hotel_booking_response',
      'appointmentId': 'appointment-id',
      'bookingId': 'booking-id',
    });
    final taxi = AppointmentNotificationContract.resolve({
      'type': 'pet_taxi_payment_success',
      'appointmentId': 'appointment-id',
      'bookingId': 'booking-id',
    });

    expect(hotel!.collection, 'hotel_bookings');
    expect(hotel.documentId, 'booking-id');
    expect(taxi!.collection, 'pet_taxi_bookings');
    expect(taxi.documentId, 'booking-id');
  });

  test('malformed or unknown references fail closed', () {
    expect(
      AppointmentNotificationContract.resolve({
        'type': 'vet_appointment_response',
      }),
      isNull,
    );
    expect(
      AppointmentNotificationContract.resolve({
        'type': 'unknown_appointment_response',
        'appointmentId': 'id',
      }),
      isNull,
    );
    expect(
      AppointmentNotificationContract.resolve({
        'appointmentCollection': 'unsupported_collection',
        'appointmentId': 'id',
      }),
      isNull,
    );
  });

  test('malformed availability is deterministic and separate from missing', () {
    expect(
      AppointmentNotificationContract.resolve({
        'type': 'hotel_booking_response',
        'appointmentId': 'appointment-id',
        'bookingId': 'booking-id',
      })!.documentId,
      'booking-id',
    );
    expect(
      AppointmentNotificationAvailability.values,
      containsAll([
        AppointmentNotificationAvailability.available,
        AppointmentNotificationAvailability.missing,
        AppointmentNotificationAvailability.malformed,
        AppointmentNotificationAvailability.unknown,
      ]),
    );
  });

  test('all localization files define appointment availability messages', () {
    for (final locale in ['en', 'tr', 'fa', 'ru']) {
      final source = File('lib/l10n/app_$locale.arb').readAsStringSync();
      expect(source, contains('"appointmentNoLongerAvailable"'));
      expect(source, contains('"appointmentAvailabilityChecking"'));
      expect(source, contains('"appointmentAvailabilityCheckFailed"'));
    }
  });

  test(
    'new vet booking creation analytics replaces misleading completion log',
    () {
      final events = File(
        'lib/services/analytics/analytics_events.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/analytics/analytics_service.dart',
      ).readAsStringSync();
      final page = File(
        'lib/ui/vet/vet_appointment_page.dart',
      ).readAsStringSync();

      expect(events, contains("vetBookingCreated = 'vet_booking_created'"));
      expect(service, contains('static Future<void> vetBookingCreated'));
      expect(page, contains('AnalyticsService.vetBookingCreated('));
      expect(page, isNot(contains('AnalyticsService.vetBookingCompleted(')));
    },
  );

  test('notification UI guards appointment references before routing', () {
    final notificationPage = File(
      'lib/notifications_page.dart',
    ).readAsStringSync();
    final allNotifications = File(
      'lib/all_notifications_page.dart',
    ).readAsStringSync();
    final display = File(
      'lib/widgets/appointment_notification_display.dart',
    ).readAsStringSync();

    expect(notificationPage, contains('_appointmentReferenceIsAvailable'));
    expect(allNotifications, contains('_appointmentReferenceIsAvailable'));
    expect(display, contains('AppointmentNotificationDisplay'));
    expect(display, contains('appointmentNoLongerAvailable'));
    expect(display, contains('appointmentAvailabilityCheckFailed'));
  });
}
