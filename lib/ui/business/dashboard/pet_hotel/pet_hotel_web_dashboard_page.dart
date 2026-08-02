import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../web/business_web_dashboard_shell.dart';
import 'package:barky_matches_fixed/ui/business/finance/business_revenue_dashboard.dart';
import 'pet_hotel_dashboard_page.dart';

class PetHotelWebDashboardPage extends StatelessWidget {
  const PetHotelWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });
  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  Widget build(BuildContext context) => BusinessWebDashboardShell(
    businessName: businessDashboardName(businessData, 'Pet Hotel Dashboard'),
    sectorName: 'Pet Hotel',
    destinations: [
      BusinessWebDashboardDestination(
        label: 'Operations',
        subtitle: 'Bookings, capacity and services',
        icon: LucideIcons.layoutDashboard,
        child: PetHotelDashboardPage(
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
          recordLabel: 'bookings',
        ),
      ),
    ],
  );
}
