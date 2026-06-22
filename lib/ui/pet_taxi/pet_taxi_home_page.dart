import 'package:flutter/material.dart';

import 'pet_taxi_my_rides_tab.dart';
import 'pet_taxi_request_tab.dart';

class PetTaxiHomePage extends StatelessWidget {
  const PetTaxiHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Request Ride'),
              Tab(text: 'My Rides'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                PetTaxiRequestTab(),
                PetTaxiMyRidesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}