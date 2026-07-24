import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'pet_taxi_my_rides_tab.dart';
import 'pet_taxi_request_tab.dart';

class PetTaxiHomePage extends StatelessWidget {
  const PetTaxiHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.petTaxiRequestRideTab),
              Tab(text: l10n.myRides),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [PetTaxiRequestTab(), PetTaxiMyRidesTab()],
            ),
          ),
        ],
      ),
    );
  }
}
