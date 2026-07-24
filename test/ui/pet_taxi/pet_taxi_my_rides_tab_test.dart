import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_my_rides_tab.dart';

void main() {
  group('Pet Taxi ride grouping', () {
    test('groups every production booking status', () {
      const active = [
        'pending',
        'awaiting_user_payment',
        'confirmed_paid',
        'payment_failed',
        'driver_on_the_way',
        'arrived',
        'pet_picked_up',
        'on_trip',
      ];
      const completed = ['completed'];
      const cancelled = [
        'refund_pending',
        'refunded',
        'cancelled_by_user',
        'cancelled_by_business',
      ];

      for (final status in active) {
        expect(
          petTaxiRideFilterForStatus(status),
          PetTaxiRideFilter.active,
          reason: status,
        );
      }
      for (final status in completed) {
        expect(
          petTaxiRideFilterForStatus(status),
          PetTaxiRideFilter.completed,
          reason: status,
        );
      }
      for (final status in cancelled) {
        expect(
          petTaxiRideFilterForStatus(status),
          PetTaxiRideFilter.cancelled,
          reason: status,
        );
      }
    });

    test('keeps planning-era terminal statuses safe for migrated data', () {
      expect(petTaxiRideFilterForStatus('rated'), PetTaxiRideFilter.completed);
      for (final status in ['cancelled', 'timeout', 'no_driver_found']) {
        expect(
          petTaxiRideFilterForStatus(status),
          PetTaxiRideFilter.cancelled,
          reason: status,
        );
      }
    });

    test('treats missing and unknown statuses as active legacy rides', () {
      expect(petTaxiRideFilterForStatus(null), PetTaxiRideFilter.active);
      expect(
        petTaxiRideFilterForStatus('legacy_pending'),
        PetTaxiRideFilter.active,
      );
    });
  });

  group('Pet Taxi ride ordering', () {
    test('places active rides before completed and cancelled rides', () {
      final rides = [
        {'status': 'cancelled_by_user', 'scheduledAt': '2026-07-01T09:00:00Z'},
        {'status': 'completed', 'scheduledAt': '2026-07-02T09:00:00Z'},
        {'status': 'pending', 'scheduledAt': '2026-07-03T09:00:00Z'},
      ]..sort(comparePetTaxiRides);

      expect(rides.map((ride) => ride['status']), [
        'pending',
        'completed',
        'cancelled_by_user',
      ]);
    });

    test('orders active rides soonest first', () {
      final rides = [
        {'status': 'pending', 'scheduledAt': '2026-07-03T09:00:00Z'},
        {'status': 'on_trip', 'scheduledAt': '2026-07-01T09:00:00Z'},
      ]..sort(comparePetTaxiRides);

      expect(rides.first['status'], 'on_trip');
    });

    test(
      'orders historical rides newest first and tolerates missing dates',
      () {
        final rides = [
          {'status': 'completed'},
          {'status': 'completed', 'scheduledAt': '2026-07-01T09:00:00Z'},
          {'status': 'completed', 'scheduledAt': '2026-07-03T09:00:00Z'},
        ]..sort(comparePetTaxiRides);

        expect(rides[0]['scheduledAt'], '2026-07-03T09:00:00Z');
        expect(rides[1]['scheduledAt'], '2026-07-01T09:00:00Z');
        expect(rides[2]['scheduledAt'], isNull);
      },
    );
  });

  test('parses ISO, DateTime, epoch, and missing legacy date values', () {
    final date = DateTime.utc(2026, 7, 24, 10, 30);
    expect(petTaxiRideDate(date), date);
    expect(petTaxiRideDate(date.toIso8601String()), date);
    expect(
      petTaxiRideDate(date.millisecondsSinceEpoch),
      DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch),
    );
    expect(petTaxiRideDate(null), isNull);
    expect(petTaxiRideDate('not-a-date'), isNull);
  });
}
