import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';

void main() {
  final point = const PetTaxiLocationPoint(
    formattedAddress: 'Laboratory Street 1, Istanbul',
    lat: 41.0082,
    lng: 28.9784,
  );

  test('debounces address search and returns suggestions', () async {
    final queries = <String>[];
    List<PetTaxiLocationPoint>? results;
    final controller = PetTaxiLocationSearchController(
      debounceDuration: const Duration(milliseconds: 20),
      search: (query) async {
        queries.add(query);
        return [point];
      },
    );

    controller.schedule(
      'Istanbul',
      onSearching: () {},
      onResults: (value) => results = value,
      onError: (_) => fail('unexpected search error'),
      onCleared: () => fail('unexpected clear'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(queries, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(queries, ['Istanbul']);
    expect(results, [point]);
    controller.dispose();
  });

  test('a newer query prevents stale suggestions from being applied', () async {
    final pending = <String, Completer<List<PetTaxiLocationPoint>>>{};
    List<PetTaxiLocationPoint>? results;
    final controller = PetTaxiLocationSearchController(
      debounceDuration: Duration.zero,
      search: (query) async {
        final completer = Completer<List<PetTaxiLocationPoint>>();
        pending[query] = completer;
        return completer.future;
      },
    );

    void schedule(String query) => controller.schedule(
      query,
      onSearching: () {},
      onResults: (value) => results = value,
      onError: (_) => fail('unexpected search error'),
      onCleared: () => fail('unexpected clear'),
    );

    schedule('first address');
    await Future<void>.delayed(Duration.zero);
    schedule('second address');
    await Future<void>.delayed(Duration.zero);
    pending['first address']!.complete([point]);
    await Future<void>.delayed(Duration.zero);
    expect(results, isNull);

    pending['second address']!.complete([
      PetTaxiLocationPoint(
        formattedAddress: 'second address',
        lat: point.lat,
        lng: point.lng,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(results!.single.formattedAddress, 'second address');
    controller.dispose();
  });

  test('short queries clear suggestions without searching', () {
    var cleared = 0;
    var searched = false;
    final controller = PetTaxiLocationSearchController(
      search: (_) async {
        searched = true;
        return const [];
      },
    );

    controller.schedule(
      'abc',
      onSearching: () {},
      onResults: (_) {},
      onError: (_) => fail('unexpected search error'),
      onCleared: () => cleared++,
    );

    expect(cleared, 1);
    expect(searched, isFalse);
    controller.dispose();
  });

  test(
    'search errors are surfaced without changing the location contract',
    () async {
      Object? error;
      final controller = PetTaxiLocationSearchController(
        debounceDuration: Duration.zero,
        search: (_) async => throw StateError('search unavailable'),
      );

      controller.schedule(
        'address query',
        onSearching: () {},
        onResults: (_) {},
        onError: (value) => error = value,
        onCleared: () => fail('unexpected clear'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(error, isA<StateError>());
      controller.dispose();
    },
  );

  test('selected locations preserve the existing booking map shape', () {
    expect(point.toMap(), {
      'formattedAddress': 'Laboratory Street 1, Istanbul',
      'lat': 41.0082,
      'lng': 28.9784,
    });
  });
}
