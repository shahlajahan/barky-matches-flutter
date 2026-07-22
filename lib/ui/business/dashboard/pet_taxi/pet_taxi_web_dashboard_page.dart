import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../web/business_web_dashboard_shell.dart';
import '../vet/web/revenue/vet_revenue_repository.dart';
import '../vet/web/revenue/vet_revenue_section.dart';
import 'pet_taxi_dashboard_page.dart';

class PetTaxiWebDashboardPage extends StatelessWidget {
  const PetTaxiWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });
  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(businessData, 'Pet Taxi Dashboard'),
    sectorName: 'Pet Taxi',
    destinations: [
      BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Bookings and dispatch overview',
        icon: LucideIcons.layoutDashboard,
        child: PetTaxiDashboardPage(
          businessId: businessId,
          businessData: businessData,
        ),
      ),
      BusinessWebDashboardDestination(
        label: 'Revenue',
        subtitle: 'Verified payments and settlement data',
        icon: LucideIcons.lineChart,
        child: VetRevenueSection(
          businessId: businessId,
          repository: VetRevenueRepository(collectionName: 'pet_taxi_bookings'),
        ),
      ),
    ],
  );
}
