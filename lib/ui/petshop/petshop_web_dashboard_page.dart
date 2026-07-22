import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../business/dashboard/web/business_web_dashboard_shell.dart';
import '../business/dashboard/vet/web/revenue/vet_revenue_repository.dart';
import '../business/dashboard/vet/web/revenue/vet_revenue_section.dart';
import 'petshop_dashboard_page.dart';

class PetShopWebDashboardPage extends StatelessWidget {
  const PetShopWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });
  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(businessData, 'Petshop Dashboard'),
    sectorName: 'Petshop',
    destinations: [
      const BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Orders, products and returns',
        icon: LucideIcons.layoutDashboard,
        child: PetShopDashboardPage(),
      ),
      BusinessWebDashboardDestination(
        label: 'Revenue',
        subtitle: 'Verified payments and payout data',
        icon: LucideIcons.lineChart,
        child: VetRevenueSection(
          businessId: businessId,
          repository: VetRevenueRepository(
            collectionName: 'sellerOrders',
            businessIdField: 'shopId',
          ),
        ),
      ),
    ],
  );
}
