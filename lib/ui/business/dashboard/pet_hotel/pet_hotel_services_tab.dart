import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/sections/vet_dashboard_services_tab.dart';

class PetHotelServicesTab extends StatelessWidget {
  final String businessId;

  const PetHotelServicesTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return VetDashboardServicesTab(businessId: businessId);
  }
}
