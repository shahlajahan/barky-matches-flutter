import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/add_adoption_pet_page.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/add_adoption_pet_detail_page.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/adoption_pets_tab.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/sections/adoption_center_dashboard_overview_tab.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/sections/adoption_center_dashboard_gallery_tab.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/adoption_center_requests_tab.dart';

enum AdoptionCenterDashboardSection { overview, pets, gallery, requests }

class AdoptionCenterDashboardPage extends StatefulWidget {
  final String businessId;

  final Map<String, dynamic> businessData;

  const AdoptionCenterDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<AdoptionCenterDashboardPage> createState() =>
      _AdoptionCenterDashboardPageState();
}

class _AdoptionCenterDashboardPageState
    extends State<AdoptionCenterDashboardPage> {
  static const List<String> _adoptionPetTemplates = [
    'Dog',

    'Cat',

    'Puppy',

    'Kitten',

    'Special Needs Pet',

    'Senior Dog',

    'Senior Cat',

    'Rescue Dog',

    'Rescue Cat',
  ];

  AdoptionCenterDashboardSection _selected =
      AdoptionCenterDashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    /// =============================
    /// ➕ ADD PET
    /// =============================

    if (appState.businessSubPage == BusinessSubPage.addService) {
      return AddAdoptionPetPage(
        pets: _adoptionPetTemplates,

        title: 'Add Adoption Pet',

        sectionTitle: 'Select Pet Type',

        fallbackIcon: Icons.pets,
      );
    }

    /// =============================
    /// ✏️ ADD PET DETAIL
    /// =============================

    if (appState.businessSubPage == BusinessSubPage.addServiceDetail) {
      return AddAdoptionPetDetailPage(
        businessId: widget.businessId,

        petTitle: appState.selectedServiceTitle ?? '',

        petId: appState.editingServiceId,

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),

                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selected) {
      /// =============================
      /// OVERVIEW
      /// =============================

      case AdoptionCenterDashboardSection.overview:
        return AdoptionCenterDashboardOverviewTab(
          key: const ValueKey('overview'),

          businessId: widget.businessId,

          businessData: widget.businessData,
        );

      /// =============================
      /// PETS
      /// =============================

      case AdoptionCenterDashboardSection.pets:
        return AdoptionPetsTab(
          key: const ValueKey('pets'),

          businessId: widget.businessId,
        );

      /// =============================
      /// GALLERY
      /// =============================

      case AdoptionCenterDashboardSection.gallery:
        return AdoptionCenterDashboardGalleryTab(
          key: const ValueKey('gallery'),

          businessId: widget.businessId,
        );

      /// =============================
      /// REQUESTS
      /// =============================

      case AdoptionCenterDashboardSection.requests:
        return AdoptionCenterRequestsTab(
          key: const ValueKey('requests'),

          businessId: widget.businessId,
        );
    }
  }
}

class _TopTabs extends StatelessWidget {
  final AdoptionCenterDashboardSection selected;

  final ValueChanged<AdoptionCenterDashboardSection> onChange;

  const _TopTabs({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        AdoptionCenterDashboardSection.overview,

        'Overview',

        LucideIcons.layoutDashboard,
      ),

      (AdoptionCenterDashboardSection.pets, 'Pets', Icons.pets),

      (AdoptionCenterDashboardSection.gallery, 'Gallery', LucideIcons.image),

      (
        AdoptionCenterDashboardSection.requests,

        'Requests',

        LucideIcons.heartHandshake,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),

      height: 64,

      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),

        scrollDirection: Axis.horizontal,

        itemCount: items.length,

        separatorBuilder: (_, __) => const SizedBox(width: 10),

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
                    color: Colors.black.withOpacity(0.06),

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
