import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';
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

  test('actual approved non-Pet-Taxi projection shape is excluded', () {
    final projections = [
      {
        'sectors': ['veterinary'],
        'publicSectorData': {'vet': {}, 'veterinarian': {}, 'veterinary': {}},
      },
      {
        'sectors': ['adoption_center'],
        'publicSectorData': {'adoptionCenter': {}, 'adoption_center': {}},
      },
      {
        'sectors': ['pet_hotel'],
        'publicSectorData': {'hotel': {}, 'pet_hotel': {}},
      },
      {
        'sectors': ['pet_shop'],
        'publicSectorData': {'petshop': {}},
      },
      {
        'sectors': ['groomer'],
        'publicSectorData': {'groomy': {}},
      },
    ];

    for (var index = 0; index < projections.length; index++) {
      expect(
        PetTaxiBusinessRepository().mapPetTaxiBusiness(
          'approved-$index',
          projections[index],
        ),
        isNull,
      );
    }
  });

  test(
    'non-Pet-Taxi canonical sectors remain authoritative over public payload',
    () {
      final result = PetTaxiBusinessRepository().mapPetTaxiBusiness('vet-2', {
        'status': 'approved',
        'sectors': ['veterinary'],
        'publicSectorData': {
          'pet_taxi': {'isAvailable': true},
        },
      });

      expect(result, isNull);
    },
  );

  test('zero Pet Taxi businesses return no nearest business', () async {
    final repository = PetTaxiBusinessRepository(
      firestore: FakeFirebaseFirestore(),
    );
    final result = await repository.findNearestBusiness(
      pickup: const PetTaxiLocationPoint(
        formattedAddress: 'Pickup',
        lat: 41.0,
        lng: 29.0,
      ),
    );

    expect(result, isNull);
  });

  test('valid Pet Taxi business is selected as nearest', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('businesses_public').doc('taxi-1').set({
      'status': 'approved',
      'sectors': ['pet_taxi'],
      'profile': {'displayName': 'Nearest Taxi'},
      'publicSectorData': {
        'pet_taxi': {
          'isAvailable': true,
          'currentLocation': {
            'lat': 41.0,
            'lng': 29.0,
            'source': 'gps_runtime',
          },
        },
      },
    });

    final result = await PetTaxiBusinessRepository(firestore: firestore)
        .findNearestBusiness(
          pickup: const PetTaxiLocationPoint(
            formattedAddress: 'Pickup',
            lat: 41.001,
            lng: 29.001,
          ),
        );

    expect(result, isNotNull);
    expect(result!.id, 'taxi-1');
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

  test(
    'stale runtime location falls back consistently to contact location',
    () {
      final now = DateTime.now();
      final result = PetTaxiBusinessLocationResolver.resolve({
        'sectors': ['pet_taxi'],
        'contact': {
          'location': {'lat': 41.01, 'lng': 28.67},
        },
        'publicSectorData': {
          'pet_taxi': {
            'currentLocation': {
              'lat': 37.33,
              'lng': -122.02,
              'source': 'gps_runtime',
              'updatedAt': now.subtract(const Duration(hours: 1)),
            },
          },
        },
      });

      expect(
        result.sourceLabel,
        'contact.location (repairing currentLocation)',
      );
      expect(result.location['lat'], 41.01);
      expect(result.location['lng'], 28.67);
    },
  );
}
