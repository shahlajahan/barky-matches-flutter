import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'sections/pet_taxi_dashboard_bookings_tab.dart';
import 'sections/pet_taxi_dashboard_overview_tab.dart';

enum PetTaxiDashboardSection { overview, bookings }

class PetTaxiDashboardPage extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetTaxiDashboardPage({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetTaxiDashboardPage> createState() => _PetTaxiDashboardPageState();
}

class _PetTaxiDashboardPageState extends State<PetTaxiDashboardPage> {
  PetTaxiDashboardSection _selected = PetTaxiDashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.bg,
        child: Column(
          children: [
            _TopTabs(
              selected: _selected,
              onChange: (section) => setState(() => _selected = section),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _selected == PetTaxiDashboardSection.overview
                    ? PetTaxiDashboardOverviewTab(
                        key: const ValueKey('overview'),
                        businessId: widget.businessId,
                        businessData: widget.businessData,
                      )
                    : PetTaxiDashboardBookingsTab(
                        key: const ValueKey('bookings'),
                        businessId: widget.businessId,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final PetTaxiDashboardSection selected;
  final ValueChanged<PetTaxiDashboardSection> onChange;

  const _TopTabs({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        PetTaxiDashboardSection.overview,
        'Overview',
        LucideIcons.layoutDashboard,
      ),
      (PetTaxiDashboardSection.bookings, 'Bookings', LucideIcons.calendarDays),
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
                boxShadow: AppTheme.cardShadow(opacity: 0.05),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textDark,
                      fontWeight: FontWeight.w700,
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
