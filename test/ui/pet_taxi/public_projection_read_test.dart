import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/repositories/pet_taxi_business_repository.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_business_location_resolver.dart';

void main() {
  test('Pet Taxi public adapter reads publicSectorData', () {
    final result = PetTaxiBusinessRepository().mapPetTaxiBusiness('taxi-1', {
      'status': 'approved',
      'sectors': ['pet_taxi'],
      'profile': {'displayName': 'Public Taxi'},
      'contact': {'city': 'Istanbul', 'district': 'Kadikoy', 'phone': '555'},
      'publicSectorData': {
        'pet_taxi': {
          'isAvailable': true,
          'vehicle': {'vehicleType': 'Van'},
          'profileContent': {'clinicLogoUrl': 'https://example.test/logo.png'},
        },
      },
    });

    expect(result, isNotNull);
    expect(result!.name, 'Public Taxi');
    expect(result.city, 'Istanbul');
    expect(result.description, 'Van');
    expect(result.logoUrl, 'https://example.test/logo.png');
  });

  test('contaminated non-Pet-Taxi public data is rejected', () {
    final result = PetTaxiBusinessRepository().mapPetTaxiBusiness('vet-1', {
      'status': 'approved',
      'sectors': ['veterinary'],
      'profile': {'displayName': 'Contaminated Vet'},
      'publicSectorData': {
        'veterinary': {
          'profileContent': {'bio': 'Clinic'},
        },
        'pet_taxi': {'isAvailable': true},
      },
    });

    expect(result, isNull);
  });

  test('location resolver ignores contaminated Pet Taxi data', () {
    final result = PetTaxiBusinessLocationResolver.resolve({
      'sectors': ['veterinary'],
      'contact': {
        'location': {'lat': 41.0, 'lng': 29.0},
      },
      'publicSectorData': {
        'pet_taxi': {
          'currentLocation': {'lat': 40.0, 'lng': 28.0},
        },
      },
    });

    expect(result.sourceLabel, 'not_pet_taxi');
    expect(result.shouldBackfillCurrentLocation, isFalse);
    expect(result.location, isEmpty);
  });
}
