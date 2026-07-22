import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class PetTaxiMyRidesTab extends StatelessWidget {
  const PetTaxiMyRidesTab({super.key});

 @override
Widget build(BuildContext context) {
  return Center(
    child: Text(
      AppLocalizations.of(context)!.myRides,
    ),
  );
}
}
