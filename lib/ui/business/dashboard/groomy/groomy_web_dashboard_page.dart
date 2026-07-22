import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../web/business_web_dashboard_shell.dart';
import '../vet/web/revenue/vet_revenue_repository.dart';
import '../vet/web/revenue/vet_revenue_section.dart';
import 'groomy_dashboard_page.dart';

class GroomyWebDashboardPage extends StatelessWidget {
  const GroomyWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });
  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(businessData, 'Grooming Dashboard'),
    sectorName: 'Grooming',
    destinations: [
      BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Appointments, services and profile',
        icon: LucideIcons.layoutDashboard,
        child: GroomyDashboardPage(
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
          repository: VetRevenueRepository(
            collectionName: 'groomy_appointments',
          ),
        ),
      ),
    ],
  );
}
