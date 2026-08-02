import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/web/business_web_dashboard_shell.dart';

import 'adoption_center_dashboard_page.dart';
import 'adoption_impact_dashboard.dart';

class AdoptionCenterWebDashboardPage extends StatelessWidget {
  const AdoptionCenterWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(
      businessData,
      'Adoption Center Dashboard',
    ),
    sectorName: 'Adoption Center',
    destinations: [
      BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Animals, applications and shelter activity',
        icon: LucideIcons.layoutDashboard,
        child: AdoptionCenterDashboardPage(
          businessId: businessId,
          businessData: businessData,
        ),
      ),
      BusinessWebDashboardDestination(
        label: 'Impact',
        subtitle: 'Adoption performance and shelter activity',
        icon: LucideIcons.heartHandshake,
        child: AdoptionImpactDashboard(
          businessId: businessId,
          onAddAnimal: context.read<AppState>().openAddService,
        ),
      ),
    ],
  );
}
