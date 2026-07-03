import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PetTaxiLocationPermissionService {
  const PetTaxiLocationPermissionService();

  Future<bool> ensureForegroundPermission(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _showLocationServicesDialog(context);
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await _showAppSettingsDialog(context);
      return false;
    }

    await _showPermissionDeniedDialog(context);
    return false;
  }

  Future<void> _showLocationServicesDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Turn On Location Services'),
          content: const Text(
            'Pet Taxi needs location services enabled to show your live position on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Allow Location Access'),
          content: const Text(
            'Pet Taxi needs location permission to enable My Location and center the map on you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAppSettingsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Location Permission Blocked'),
          content: const Text(
            'Location access is blocked for Pet Taxi. Open app settings to allow location permission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}
