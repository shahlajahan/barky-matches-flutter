import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../web/business_web_dashboard_shell.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_widgets.dart';
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
        child: SellerFinanceSummarySection(
          businessId: businessId,
          recordLabel: 'appointments',
        ),
      ),
    ],
  );
}
