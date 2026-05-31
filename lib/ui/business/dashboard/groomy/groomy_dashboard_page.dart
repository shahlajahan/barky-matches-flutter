import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_service_detail_page.dart';

import 'dashboard/groomy_services_tab.dart';

import 'sections/groomy_dashboard_overview_tab.dart';
import 'sections/groomy_dashboard_gallery_tab.dart';
import 'sections/groomy_dashboard_appointments_tab.dart';

enum GroomyDashboardSection { overview, services, gallery, appointments }

class GroomyDashboardPage extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const GroomyDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<GroomyDashboardPage> createState() => _GroomyDashboardPageState();
}

class _GroomyDashboardPageState extends State<GroomyDashboardPage> {
  static const List<String> _groomingServiceTemplates = [
    'Full Grooming',
    'Bath & Dry',
    'Nail Trimming',
    'Hair Cutting',
    'Ear Cleaning',
    'Teeth Cleaning',
    'Puppy Grooming',
    'Cat Grooming',
    'SPA Grooming',
  ];

  GroomyDashboardSection _selected = GroomyDashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    /// =============================
    /// ➕ ADD SERVICE
    /// =============================

    if (appState.businessSubPage == BusinessSubPage.addService) {
      return AddServicesPage(
        businessId: widget.businessId,
        services: _groomingServiceTemplates,
        title: 'Add Grooming Service',
        sectionTitle: 'Select Grooming Service',
        fallbackIcon: LucideIcons.scissors,
      );
    }

    /// =============================
    /// ✏️ ADD SERVICE DETAIL
    /// =============================

    if (appState.businessSubPage == BusinessSubPage.addServiceDetail) {
      return AddServiceDetailPage(
        businessId: widget.businessId,
        serviceTitle: appState.selectedServiceTitle ?? '',
        serviceId: appState.editingServiceId,
        existingData: appState.editingServiceData,
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.bg,
        child: Column(
          children: [
            _TopTabs(
              selected: _selected,
              onChange: (section) {
                setState(() {
                  _selected = section;
                });
              },
            ),

           Expanded(
  child: IndexedStack(
    index: _selected.index,
    children: [
      GroomyDashboardOverviewTab(
        key: const ValueKey('overview'),
        businessId: widget.businessId,
        businessData: widget.businessData,
      ),

      GroomyServicesTab(
        key: const ValueKey('services'),
        businessId: widget.businessId,
      ),

      GroomyDashboardGalleryTab(
        key: const ValueKey('gallery'),
        businessId: widget.businessId,
      ),

      GroomyDashboardAppointmentsTab(
        key: const ValueKey('appointments'),
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
  /*

  Widget _buildContent() {
    switch (_selected) {
      /// =============================
      /// OVERVIEW
      /// =============================

      case GroomyDashboardSection.overview:
        return GroomyDashboardOverviewTab(
          key: const ValueKey('overview'),
          businessId: widget.businessId,
          businessData: widget.businessData,
        );

      /// =============================
      /// SERVICES
      /// =============================

      case GroomyDashboardSection.services:
        return GroomyServicesTab(
          key: const ValueKey('services'),
          businessId: widget.businessId,
        );

      /// =============================
      /// GALLERY
      /// =============================

      case GroomyDashboardSection.gallery:
        return GroomyDashboardGalleryTab(
          key: const ValueKey('gallery'),
          businessId: widget.businessId,
        );

      /// =============================
      /// APPOINTMENTS
      /// =============================

      case GroomyDashboardSection.appointments:
        return GroomyDashboardAppointmentsTab(
          key: const ValueKey('appointments'),
          businessId: widget.businessId,
        );
    }
  }
  */
}

class _TopTabs extends StatelessWidget {
  final GroomyDashboardSection selected;

  final ValueChanged<GroomyDashboardSection> onChange;

  const _TopTabs({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        GroomyDashboardSection.overview,
        'Overview',
        LucideIcons.layoutDashboard,
      ),

      (GroomyDashboardSection.services, 'Services', LucideIcons.scissors),

      (GroomyDashboardSection.gallery, 'Gallery', LucideIcons.image),

      (
        GroomyDashboardSection.appointments,
        'Appointments',
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

        itemBuilder: (context, index) {
          final (section, title, icon) = items[index];

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
