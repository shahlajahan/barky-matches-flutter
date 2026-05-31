import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'sections/vet_dashboard_overview_tab.dart';

import 'sections/vet_dashboard_appointments_tab.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_service_detail_page.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_detail_page.dart';

enum VetDashboardSection { overview, appointments }

class VetDashboardPage extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const VetDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<VetDashboardPage> createState() => _VetDashboardPageState();
}

class _VetDashboardPageState extends State<VetDashboardPage> {
  VetDashboardSection _selected = VetDashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    /// 🔥🔥🔥 AUTO OPEN APPOINTMENT (اینجا اضافه کن)
    if (appState.selectedAppointmentId != null) {
      return AppointmentDetailPage(
        appointmentId: appState.selectedAppointmentId!,
      );
    }

    /// 🔴 HANDLE SUB PAGE
    if (appState.businessSubPage == BusinessSubPage.addService) {
      return AddServicesPage(businessId: widget.businessId);
    }
    if (appState.businessSubPage == BusinessSubPage.addServiceDetail) {
      return AddServiceDetailPage(
        businessId: widget.businessId,
        serviceTitle: appState.selectedServiceTitle ?? '',
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.bg,
        child: Column(
          children: [
            /// 🟣 TABS
            _TopTabs(
              selected: _selected,
              onChange: (s) => setState(() => _selected = s),
            ),

            /// 📦 CONTENT
            Expanded(
  child: IndexedStack(
    index: _selected == VetDashboardSection.overview ? 0 : 1,
    children: [
      VetDashboardOverviewTab(
        key: const PageStorageKey('vet_overview_scroll'),
        businessId: widget.businessId,
        businessData: widget.businessData,
      ),
      VetDashboardAppointmentsTab(
        key: const PageStorageKey('vet_appointments_scroll'),
        businessId: widget.businessId,
      ),
    ],
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selected) {
      case VetDashboardSection.overview:
        return VetDashboardOverviewTab(
          key: const ValueKey('overview'),
          businessId: widget.businessId,
          businessData: widget.businessData,
        );

      case VetDashboardSection.appointments:
        return VetDashboardAppointmentsTab(
          key: const ValueKey('appointments'),
          businessId: widget.businessId,
        );
    }
  }
}

/// ================= TABS =================
class _TopTabs extends StatelessWidget {
  final VetDashboardSection selected;
  final Function(VetDashboardSection) onChange;

  const _TopTabs({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        VetDashboardSection.overview,
        l10n.overviewTab,
        LucideIcons.layoutDashboard,
      ),
      (
        VetDashboardSection.appointments,
        l10n.appointmentsTab,
        LucideIcons.calendar,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (section, title, icon) = items[i];
          final isSelected = selected == section;

          return GestureDetector(
            onTap: () => onChange(section),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF9E1B4F) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF9E1B4F),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9E1B4F),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
