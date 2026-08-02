import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.turnOnLocationServices),
          content: Text(l10n.petTaxiLocationServicesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: Text(l10n.openSettings),
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
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.allowLocationAccess),
          content: Text(l10n.petTaxiLocationPermissionMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
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
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.locationPermissionBlocked),
          content: Text(l10n.petTaxiLocationBlockedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: Text(l10n.openSettings),
            ),
          ],
        );
      },
    );
  }
}
