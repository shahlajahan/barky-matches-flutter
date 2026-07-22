import 'package:barky_matches_fixed/ui/business/dashboard/business_dashboard_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit veterinary sector ignores stale Pet Taxi payload', () {
    final sectors = resolveBusinessDashboardSectors(
      ['veterinary'],
      {
        'sectorData': {
          'veterinary': {'profile': {}},
          'pet_taxi': {},
        },
      },
    );

    expect(sectors, [BusinessSector.vet]);
  });

  test('explicit Hotel sector ignores unrelated Pet Taxi payload', () {
    final sectors = resolveBusinessDashboardSectors(
      ['pet_hotel'],
      {
        'sectorData': {'hotel': {}, 'pet_taxi': {}},
      },
    );

    expect(sectors, [BusinessSector.petHotel]);
  });

  test('legitimate explicit multi-sector business keeps every sector', () {
    final sectors = resolveBusinessDashboardSectors([
      'veterinary',
      'pet_taxi',
      'groomer',
    ], const {});

    expect(sectors, [
      BusinessSector.vet,
      BusinessSector.petTaxi,
      BusinessSector.groomy,
    ]);
  });

  test('substring-like metadata cannot create a sector', () {
    final sectors = resolveBusinessDashboardSectors(
      ['veterinary'],
      const {
        'businessType': 'pet_taxi_partner_candidate',
        'category': 'hotel_and_pet_taxi_services',
      },
    );

    expect(sectors, [BusinessSector.vet]);
  });

  test('legacy document without sectors uses exact aliases', () {
    final sectors = resolveBusinessDashboardSectors(const [], const {
      'sectorData': {'pet_taxi': {}},
    });

    expect(sectors, [BusinessSector.petTaxi]);
  });

  test('legacy fallback does not use broad substring matching', () {
    final sectors = resolveBusinessDashboardSectors(const [], const {
      'businessType': 'not_a_pet_taxi_business',
    });

    expect(sectors, isEmpty);
  });
}
