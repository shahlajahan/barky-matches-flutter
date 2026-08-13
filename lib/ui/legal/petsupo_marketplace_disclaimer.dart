import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

/// Shows the intermediary acknowledgement immediately before a transaction.
Future<bool> showPetSupoMarketplaceDisclaimer(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        title: Text(l10n.marketplaceDisclaimerTitle),
        content: SingleChildScrollView(
          child: Text(l10n.marketplaceDisclaimerMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.marketplaceDisclaimerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.marketplaceDisclaimerAccept),
          ),
        ],
      );
    },
  );
  return result == true;
}
