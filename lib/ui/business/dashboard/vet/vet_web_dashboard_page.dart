import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_service_detail_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_detail_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/sections/vet_dashboard_appointments_tab.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/sections/vet_dashboard_overview_tab.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/web/revenue/vet_revenue_section.dart';

enum VetWebDashboardSection { overview, appointments, revenue }

class VetWebDashboardPage extends StatefulWidget {
  const VetWebDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  final String businessId;
  final Map<String, dynamic> businessData;

  @override
  State<VetWebDashboardPage> createState() => _VetWebDashboardPageState();
}

class _VetWebDashboardPageState extends State<VetWebDashboardPage> {
  VetWebDashboardSection _selected = VetWebDashboardSection.overview;

  String get _businessName {
    final profile =
        (widget.businessData['profile'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    for (final value in [
      profile['businessName'],
      widget.businessData['businessName'],
      widget.businessData['name'],
    ]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Veterinary Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final selectedAppointmentId = context.select<AppState, String?>(
      (state) => state.selectedAppointmentId,
    );
    final businessSubPage = context.select<AppState, BusinessSubPage>(
      (state) => state.businessSubPage,
    );
    final selectedServiceTitle = context.select<AppState, String?>(
      (state) => state.selectedServiceTitle,
    );

    Widget? overlay;
    if (selectedAppointmentId != null) {
      overlay = AppointmentDetailPage(appointmentId: selectedAppointmentId);
    } else if (businessSubPage == BusinessSubPage.addService) {
      overlay = AddServicesPage(businessId: widget.businessId);
    } else if (businessSubPage == BusinessSubPage.addServiceDetail) {
      overlay = AddServiceDetailPage(
        businessId: widget.businessId,
        serviceTitle: selectedServiceTitle ?? '',
      );
    }

    return Stack(
      children: [
        ColoredBox(
          color: AppTheme.bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 248,
                child: _Sidebar(
                  businessName: _businessName,
                  selected: _selected,
                  onSelected: (section) => setState(() => _selected = section),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _Header(section: _selected, businessName: _businessName),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1680),
                          child: IndexedStack(
                            index: _selected.index,
                            children: [
                              VetDashboardOverviewTab(
                                key: const ValueKey('web-vet-overview'),
                                businessId: widget.businessId,
                                businessData: widget.businessData,
                              ),
                              VetDashboardAppointmentsTab(
                                key: const ValueKey('web-vet-appointments'),
                                businessId: widget.businessId,
                              ),
                              VetRevenueSection(
                                key: const ValueKey('web-vet-revenue'),
                                businessId: widget.businessId,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (overlay != null) Positioned.fill(child: overlay),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.businessName,
    required this.selected,
    required this.onSelected,
  });

  final String businessName;
  final VetWebDashboardSection selected;
  final ValueChanged<VetWebDashboardSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        VetWebDashboardSection.overview,
        l10n.overviewTab,
        LucideIcons.layoutDashboard,
      ),
      (
        VetWebDashboardSection.appointments,
        l10n.appointmentsTab,
        LucideIcons.calendarDays,
      ),
      (
        VetWebDashboardSection.revenue,
        l10n.vetRevenueTitle,
        LucideIcons.barChart3,
      ),
    ];
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.stethoscope,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PetSupo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.vetWebVeterinaryLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              businessName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            for (final item in items) ...[
              _SidebarItem(
                label: item.$2,
                icon: item.$3,
                selected: item.$1 == selected,
                onTap: () => onSelected(item.$1),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF9E1B4F) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: selected ? Colors.white : const Color(0xFF6B5560),
          ),
          const SizedBox(width: 11),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF4B3942),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.section, required this.businessName});
  final VetWebDashboardSection section;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, subtitle) = switch (section) {
      VetWebDashboardSection.overview => (
        l10n.overviewTab,
        l10n.vetWebOverviewSubtitle,
      ),
      VetWebDashboardSection.appointments => (
        l10n.appointmentsTab,
        l10n.vetWebAppointmentsSubtitle,
      ),
      VetWebDashboardSection.revenue => (
        l10n.vetRevenueTitle,
        l10n.vetWebRevenueSubtitle,
      ),
    };
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECE6E9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.building2, size: 18, color: Color(0xFF9E1B4F)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              businessName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
