import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/web/business_web_dashboard_shell.dart';
import 'package:barky_matches_fixed/ui/business/finance/business_revenue_dashboard.dart';

import 'vet_dashboard_page.dart';

class VetWebDashboardPage extends StatelessWidget {
  const VetWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(businessData, 'Veterinary Dashboard'),
    sectorName: 'Veterinary',
    destinations: [
      BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Appointments and clinic overview',
        icon: LucideIcons.layoutDashboard,
        child: VetDashboardPage(
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
          recordLabel: 'appointments',
        ),
      ),
    ],
  );
}
