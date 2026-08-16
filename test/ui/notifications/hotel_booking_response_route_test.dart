import 'dart:io';

import 'package:barky_matches_fixed/ui/appointments/hotel_booking_notification_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hotel_booking_response notification routing', () {
    test('cancelled_by_user opens detail state instead of payment flow', () {
      expect(
        hotelBookingResponseDestination('cancelled_by_user'),
        HotelBookingNotificationDestination.detail,
      );
      expect(hotelBookingResponseOpensPayment('cancelled_by_user'), isFalse);
      expect(hotelBookingCanShowPaymentAction('cancelled_by_user'), isFalse);
      expect(hotelBookingCanShowCancelAction('cancelled_by_user'), isFalse);
    });

    test('terminal and non-payable statuses do not open payment flow', () {
      const statuses = [
        'pending',
        'confirmed',
        'confirmed_paid',
        'checked_in',
        'rejected',
        'cancelled_by_user',
        'cancelled_by_hotel',
        'completed',
        'payment_expired',
        'expired',
      ];

      for (final status in statuses) {
        expect(
          hotelBookingResponseOpensPayment(status),
          isFalse,
          reason: status,
        );
      }
    });

    test('terminal statuses hide payment and cancel actions', () {
      for (final status in hotelBookingTerminalStatuses) {
        expect(
          hotelBookingCanShowPaymentAction(status),
          isFalse,
          reason: status,
        );
        expect(
          hotelBookingCanShowCancelAction(status),
          isFalse,
          reason: status,
        );
      }
    });

    test('cancelled_by_hotel rejected expiry and completed are read-only', () {
      const statuses = [
        'cancelled_by_hotel',
        'rejected',
        'payment_expired',
        'expired',
        'completed',
      ];

      for (final status in statuses) {
        expect(
          hotelBookingCanShowPaymentAction(status),
          isFalse,
          reason: status,
        );
        expect(
          hotelBookingCanShowCancelAction(status),
          isFalse,
          reason: status,
        );
      }
    });

    test('awaiting_payment remains the only payable hotel response', () {
      expect(
        hotelBookingResponseDestination('awaiting_payment'),
        HotelBookingNotificationDestination.payment,
      );
      expect(hotelBookingResponseOpensPayment(' awaiting_payment '), isTrue);
      expect(hotelBookingCanShowPaymentAction('awaiting_payment'), isTrue);
    });

    test('active cancellable statuses preserve cancel action', () {
      const statuses = [
        'pending',
        'awaiting_payment',
        'confirmed',
        'confirmed_paid',
      ];

      for (final status in statuses) {
        expect(hotelBookingCanShowCancelAction(status), isTrue, reason: status);
      }
    });

    test('confirmed paid reaches customer detail state', () {
      expect(
        hotelBookingResponseDestination('confirmed_paid'),
        HotelBookingNotificationDestination.detail,
      );
    });

    test(
      'AppState preserves booking id and hotel collection in route payload',
      () {
        final source = File('lib/app_state.dart').readAsStringSync();

        expect(source, contains("type.contains('hotel_booking_response')"));
        expect(source, contains("payload['appointmentId']?.toString()"));
        expect(source, contains("payload['bookingId']?.toString()"));
        expect(source, contains("collection: 'hotel_bookings'"));
        expect(
          source,
          contains(
            "payload['appointmentCollection']?.toString() ?? 'hotel_bookings'",
          ),
        );
      },
    );

    test('hotel customer detail reads public business projection', () {
      final source = File(
        'lib/ui/business/dashboard/vet/appointment_payment_page.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "final collection = _isHotelBooking ? 'businesses_public' : 'businesses';",
        ),
      );
      expect(source, contains("data['publicSectorData']"));
    });

    test('AppointmentPaymentPage uses hotel action helpers only for Hotel', () {
      final source = File(
        'lib/ui/business/dashboard/vet/appointment_payment_page.dart',
      ).readAsStringSync();

      expect(source, contains('isHotelBooking'));
      expect(source, contains('hotelBookingCanShowCancelAction'));
      expect(source, contains('hotelBookingCanShowPaymentAction'));
      expect(source, contains("status == 'awaiting_payment'"));
    });

    test('hotel business stream errors are handled locally', () {
      final source = File(
        'lib/ui/business/dashboard/vet/appointment_payment_page.dart',
      ).readAsStringSync();

      expect(source, contains('onError: (e)'));
      expect(source, contains('BUSINESS WATCH ERROR'));
      expect(source, contains('setState(() => _businessData = null)'));
    });

    test('other notification types are not changed by this route helper', () {
      final source = File('lib/app_state.dart').readAsStringSync();

      expect(source, contains("type.contains('vet_appointment_response')"));
      expect(source, contains("type.contains('groomy_appointment_response')"));
      expect(source, contains('const petTaxiUserTypes = ['));
    });
  });
}
