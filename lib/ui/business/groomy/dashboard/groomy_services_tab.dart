import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/sections/vet_dashboard_services_tab.dart';

class GroomyServicesTab extends StatelessWidget {
  final String businessId;

  const GroomyServicesTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return VetDashboardServicesTab(businessId: businessId);
  }
}
