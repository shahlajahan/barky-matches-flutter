import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_service_detail_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';

import 'pet_hotel_availability_tab.dart';
import 'pet_hotel_bookings_tab.dart';
import 'pet_hotel_dashboard_overview_tab.dart';
import 'pet_hotel_gallery_tab.dart';
import 'pet_hotel_reviews_tab.dart';
import 'pet_hotel_services_tab.dart';

enum PetHotelDashboardSection {
  overview,
  bookings,
  services,
  availability,
  reviews,
  gallery,
}

class PetHotelDashboardPage extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetHotelDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetHotelDashboardPage> createState() => _PetHotelDashboardPageState();
}

class _PetHotelDashboardPageState extends State<PetHotelDashboardPage> {
  static const List<String> _hotelServiceTemplates = [
    'Standard Room',
    'VIP Room',
    'Cat Room',
    'Daily Care',
    'Overnight Stay',
    'Long Stay',
    'Camera Access',
    'Pickup Service',
  ];

  PetHotelDashboardSection _selected = PetHotelDashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.businessSubPage == BusinessSubPage.addService) {
      return AddServicesPage(
        businessId: widget.businessId,
        services: _hotelServiceTemplates,
        title: 'Add Hotel Service',
        sectionTitle: 'Select Hotel Service',
        fallbackIcon: LucideIcons.hotel,
      );
    }

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
                setState(() => _selected = section);
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
      case PetHotelDashboardSection.overview:
        return PetHotelDashboardOverviewTab(
          key: const ValueKey('overview'),
          businessId: widget.businessId,
          businessData: widget.businessData,
        );
      case PetHotelDashboardSection.bookings:
        return PetHotelBookingsTab(
          key: const ValueKey('bookings'),
          businessId: widget.businessId,
        );
      case PetHotelDashboardSection.services:
        return PetHotelServicesTab(
          key: const ValueKey('services'),
          businessId: widget.businessId,
        );
      case PetHotelDashboardSection.availability:
        return PetHotelAvailabilityTab(
          key: const ValueKey('availability'),
          businessId: widget.businessId,
          businessData: widget.businessData,
        );
      case PetHotelDashboardSection.reviews:
        return PetHotelReviewsTab(
          key: const ValueKey('reviews'),
          businessId: widget.businessId,
        );
      case PetHotelDashboardSection.gallery:
        return PetHotelGalleryTab(
          key: const ValueKey('gallery'),
          businessId: widget.businessId,
        );
    }
  }
}

class _TopTabs extends StatelessWidget {
  final PetHotelDashboardSection selected;
  final ValueChanged<PetHotelDashboardSection> onChange;

  const _TopTabs({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        PetHotelDashboardSection.overview,
        'Overview',
        LucideIcons.layoutDashboard,
      ),
      (PetHotelDashboardSection.bookings, 'Bookings', LucideIcons.calendarDays),
      (PetHotelDashboardSection.services, 'Services', LucideIcons.hotel),
      (PetHotelDashboardSection.availability, 'Availability', LucideIcons.bed),
      (PetHotelDashboardSection.reviews, 'Reviews', LucideIcons.star),
      (PetHotelDashboardSection.gallery, 'Gallery', LucideIcons.image),
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
