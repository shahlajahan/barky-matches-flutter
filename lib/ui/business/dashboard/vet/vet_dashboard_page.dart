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
  void initState() {
    super.initState();
   // debugPrint('🏥 VetDashboardPage initState ${identityHashCode(this)}');
  }

  @override
  void didUpdateWidget(covariant VetDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint(
      '🏥 VetDashboardPage didUpdateWidget ${identityHashCode(this)} '
      'oldBusinessId=${oldWidget.businessId} newBusinessId=${widget.businessId}',
    );
  }

  @override
  void deactivate() {
    //debugPrint('🏥 VetDashboardPage deactivate ${identityHashCode(this)}');
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    debugPrint('🏥 VetDashboardPage activate ${identityHashCode(this)}');
  }

  @override
  void dispose() {
   // debugPrint('🏥 VetDashboardPage dispose ${identityHashCode(this)}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   // debugPrint('🏥 VetDashboardPage build ${identityHashCode(this)}');
    final selectedAppointmentId = context.select<AppState, String?>(
      (s) => s.selectedAppointmentId,
    );
    final businessSubPage = context.select<AppState, BusinessSubPage>(
      (s) => s.businessSubPage,
    );
    final selectedServiceTitle = context.select<AppState, String?>(
      (s) => s.selectedServiceTitle,
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
        SafeArea(
          top: false,
          child: Container(
            color: AppTheme.bg,
            child: Column(
              children: [
                /// 🟣 TABS
                _TopTabs(
                  selected: _selected,
                  onChange: (s) {
                    debugPrint(
                      '🧭 Vet tab switch current=$_selected selected=$s businessId=${widget.businessId}',
                    );
                    setState(() => _selected = s);
                  },
                ),

                /// 📦 CONTENT
                Expanded(
                  child: IndexedStack(
                    index: _selected.index,
                    children: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (overlay != null) Positioned.fill(child: overlay),
      ],
    );
  }

  List<Widget> _buildContent() {
    return [
      VetDashboardOverviewTab(
        key: const ValueKey('overview'),
        businessId: widget.businessId,
        businessData: widget.businessData,
      ),
      VetDashboardAppointmentsTab(
        key: const ValueKey('appointments'),
        businessId: widget.businessId,
      ),
    ];
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
