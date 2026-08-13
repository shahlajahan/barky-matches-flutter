import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barky_matches_fixed/services/location_permission_service.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/sections/pet_taxi_dashboard_overview_tab.dart';

Map<String, dynamic> _business({
  bool active = true,
  bool published = true,
  String complianceStatus = 'approved',
  String status = 'approved',
  bool verified = true,
}) {
  return {
    'status': status,
    'published': published,
    'verification': {'isVerified': verified},
    'sectorData': {
      'pet_taxi': {
        'isActive': active,
        'published': published,
        'compliance': {'status': complianceStatus},
      },
    },
  };
}

void main() {
  test('foreground permission accepts iOS whileInUse and always', () {
    expect(
      LocationPermissionService.acceptsForegroundPermission(
        LocationPermission.whileInUse,
      ),
      isTrue,
    );
    expect(
      LocationPermissionService.acceptsForegroundPermission(
        LocationPermission.always,
      ),
      isTrue,
    );
  });

  test('foreground permission rejects non-authorized states', () {
    expect(
      LocationPermissionService.acceptsForegroundPermission(
        LocationPermission.denied,
      ),
      isFalse,
    );
    expect(
      LocationPermissionService.acceptsForegroundPermission(
        LocationPermission.deniedForever,
      ),
      isFalse,
    );
    expect(
      LocationPermissionService.acceptsForegroundPermission(
        LocationPermission.unableToDetermine,
      ),
      isFalse,
    );
  });

  test('eligible active and published Pet Taxi can toggle availability', () {
    expect(isPetTaxiAvailabilityEligible(_business()), isTrue);
  });

  test('inactive Pet Taxi cannot toggle availability', () {
    expect(isPetTaxiAvailabilityEligible(_business(active: false)), isFalse);
  });

  test('unpublished Pet Taxi cannot toggle availability', () {
    expect(isPetTaxiAvailabilityEligible(_business(published: false)), isFalse);
  });

  test('incomplete approval cannot toggle availability', () {
    expect(
      isPetTaxiAvailabilityEligible(
        _business(complianceStatus: 'pending_review'),
      ),
      isFalse,
    );
    expect(
      isPetTaxiAvailabilityEligible(_business(status: 'pending_review')),
      isFalse,
    );
    expect(isPetTaxiAvailabilityEligible(_business(verified: false)), isFalse);
  });
}
