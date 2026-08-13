import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';

void main() {
  test('route estimates preserve the pricing contract fields', () {
    const estimate = PetTaxiRouteEstimate(
      distanceKm: 12.34,
      durationMinutes: 27,
      source: 'google_directions_driving',
      encodedPolyline: 'encoded',
    );

    expect(estimate.toMap(), {
      'distanceKm': 12.34,
      'durationMinutes': 27,
      'source': 'google_directions_driving',
      'encodedPolyline': 'encoded',
    });
  });
}
