import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../web/business_web_dashboard_shell.dart';
import 'package:barky_matches_fixed/ui/business/finance/business_revenue_dashboard.dart';
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
        child: BusinessRevenueDashboard(
          businessId: businessId,
          recordLabel: 'rides',
        ),
      ),
    ],
  );
}
