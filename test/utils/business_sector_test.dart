import 'package:barky_matches_fixed/utils/business_sector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes every supported canonical business sector', () {
    const sectors = {
      'vet': BusinessSector.vet,
      'groomy': BusinessSector.groomy,
      'pet_shop': BusinessSector.petShop,
      'pet_hotel': BusinessSector.petHotel,
      'pet_taxi': BusinessSector.petTaxi,
      'adoption_center': BusinessSector.adoptionCenter,
      'training': BusinessSector.training,
    };

    for (final entry in sectors.entries) {
      expect(BusinessSector.normalize(entry.key), entry.value);
    }
  });

  test('normalizes supported legacy pet taxi variations', () {
    for (final value in ['pet_taxi', 'pet taxi', 'pettaxi', 'petTaxi']) {
      expect(BusinessSector.normalize(value), BusinessSector.petTaxi);
    }
  });

  test('extracts canonical sectors from complete business records', () {
    final businesses = {
      BusinessSector.vet: {'sector': 'veterinary'},
      BusinessSector.groomy: {'businessType': 'groomer'},
      BusinessSector.petShop: {
        'sectorData': {'pet_shop': <String, dynamic>{}},
      },
      BusinessSector.petHotel: {'category': 'pet hotel'},
      BusinessSector.petTaxi: {
        'sectorData': {'petTaxi': <String, dynamic>{}},
      },
      BusinessSector.adoptionCenter: {
        'sectorData': {'adoptionCenter': <String, dynamic>{}},
      },
      BusinessSector.training: {
        'profile': {'businessType': 'dog training'},
      },
    };

    for (final entry in businesses.entries) {
      expect(BusinessSector.fromBusiness(entry.value), entry.key);
    }
  });

  test('keeps search aliases separate from canonical sector values', () {
    expect(
      BusinessSector.searchAliases(BusinessSector.petTaxi),
      containsAll(['pet taxi', 'pettaxi', 'taxi']),
    );
    expect(BusinessSector.normalize('pet_taxi pet taxi'), isNull);
  });

  test('routes every supported sector to its existing destination', () {
    const expected = {
      BusinessSector.vet: BusinessSectorDestination.businessDetails,
      BusinessSector.groomy: BusinessSectorDestination.businessDetails,
      BusinessSector.petShop: BusinessSectorDestination.businessDetails,
      BusinessSector.petHotel: BusinessSectorDestination.businessDetails,
      BusinessSector.petTaxi: BusinessSectorDestination.petTaxiBooking,
      BusinessSector.adoptionCenter: BusinessSectorDestination.businessDetails,
      BusinessSector.training: BusinessSectorDestination.trainingUnavailable,
    };

    for (final entry in expected.entries) {
      expect(BusinessSector.destination(entry.key), entry.value);
    }
    expect(
      BusinessSector.destination(null),
      BusinessSectorDestination.unavailable,
    );
  });
}
