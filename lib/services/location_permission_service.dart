import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static bool _explanationShownThisSession = false;
  static bool _settingsPromptShownThisSession = false;

  static bool acceptsForegroundPermission(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<bool> ensurePermission(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        await _showSettingsDialog(
          context,
          title: 'Location services are disabled',
          message: 'Enable Location Services in Settings to use this feature.',
          openSystemLocationSettings: true,
        );
      }
      return false;
    }

    var status = await Geolocator.checkPermission();
    if (acceptsForegroundPermission(status)) return true;

    if (status == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showSettingsDialogOnce(context);
      }
      return false;
    }

    if (!_explanationShownThisSession) {
      _explanationShownThisSession = true;
      if (!context.mounted) return false;
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppLocalizations.of(context)!.continueButton),
            ),
          ],
        ),
      );
      if (shouldContinue != true || !context.mounted) return false;
    }

    status = await Geolocator.requestPermission();
    if (acceptsForegroundPermission(status)) return true;

    if (status == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showSettingsDialogOnce(context);
      }
    }
    return false;
  }

  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool openSystemLocationSettings = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (openSystemLocationSettings) {
                await Geolocator.openLocationSettings();
              } else {
                await handler.openAppSettings();
              }
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  static Future<void> _showSettingsDialogOnce(BuildContext context) async {
    if (_settingsPromptShownThisSession) return;
    _settingsPromptShownThisSession = true;
    await _showSettingsDialog(
      context,
      title: 'Location permission is disabled.',
      message: 'Enable it in Settings to use nearby services.',
    );
  }
}
