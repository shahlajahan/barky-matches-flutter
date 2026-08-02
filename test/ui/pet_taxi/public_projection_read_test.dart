import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/repositories/pet_taxi_business_repository.dart';

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
}
