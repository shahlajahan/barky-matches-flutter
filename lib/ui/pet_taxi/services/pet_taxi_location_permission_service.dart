import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/services/location_permission_service.dart';

class PetTaxiLocationPermissionService {
  const PetTaxiLocationPermissionService();

  Future<bool> ensureForegroundPermission(BuildContext context) async {
    return LocationPermissionService.ensurePermission(
      context,
      title: 'Use your location for Pet Taxi',
      message:
          'Pet Taxi needs your location to set pickup and drop-off points.',
    );
  }
}
