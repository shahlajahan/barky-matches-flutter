import 'dart:io';

import 'package:barky_matches_fixed/services/business_finance_notification_types.dart';
import 'package:barky_matches_fixed/services/marketplace_order_notification_types.dart';
import 'package:barky_matches_fixed/services/marketplace_service_notification_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delayed notification has its own canonical registry', () {
    expect(
      isMarketplaceServiceNotificationType('marketplace_business_delayed'),
      isTrue,
    );
    expect(
      isMarketplaceOrderNotificationType('marketplace_business_delayed'),
      isFalse,
    );
    expect(
      isBusinessFinanceNotificationType('marketplace_business_delayed'),
      isFalse,
    );
  });

  test('in-app route forwards appointment and business identifiers', () {
    final source = File('lib/notifications_page.dart').readAsStringSync();
    expect(source, contains('isMarketplaceServiceNotificationType(rawType)'));
    expect(source, contains("'appointmentId': data['appointmentId']"));
    expect(source, contains("'bookingId': data['bookingId']"));
    expect(source, contains("'appointmentCollection':"));
    expect(source, contains("'businessId': data['businessId']"));
    expect(source, contains(".update({'isRead': true})"));
  });

  test(
    'all supported collections use the existing customer appointment router',
    () {
      final appState = File('lib/app_state.dart').readAsStringSync();
      final router = File(
        'lib/ui/appointments/user_appointment_router.dart',
      ).readAsStringSync();

      for (final collection in [
        'vet_appointments',
        'groomy_appointments',
        'hotel_bookings',
        'pet_taxi_bookings',
      ]) {
        expect(appState, contains("'$collection'"));
        expect(router, contains("case '$collection':"));
      }
      expect(appState, contains('requestUserAppointmentDetail('));
      expect(appState, contains('ProfileSubPage.myAppointments'));
    },
  );

  test('lifecycle handlers use the shared service-notification helper', () {
    final main = File('lib/main.dart').readAsStringSync();
    final appState = File('lib/app_state.dart').readAsStringSync();

    expect(main, contains('isMarketplaceServiceNotificationType(type)'));
    expect(main, contains('_initialNotificationCoordinator.retrieveOnce'));
    expect(appState, contains('isMarketplaceServiceNotificationType(type)'));
    expect(appState, contains('isGuestUser'));
    expect(appState, contains('ProfileSubPage.myAppointments'));
  });

  test('notification route contains no mutation or payment callable', () {
    final source = File('lib/app_state.dart').readAsStringSync();
    final start = source.indexOf(
      'void _handleMarketplaceBusinessDelayedNotification',
    );
    final end = source.indexOf('void handleNotificationTap', start);
    final route = source.substring(start, end);

    expect(route, isNot(contains('httpsCallable')));
    expect(route, isNot(contains('updateAppointment')));
    expect(route, isNot(contains('cancel')));
    expect(route, isNot(contains('refund')));
    expect(route, contains('requestUserAppointmentDetail'));
  });
}
