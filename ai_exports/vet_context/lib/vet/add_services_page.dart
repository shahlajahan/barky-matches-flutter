import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'add_service_detail_page.dart';

class AddServicesPage extends StatelessWidget {
  final List<String>? services;
  final String title;
  final String sectionTitle;
  final IconData fallbackIcon;
  final String businessId;
  final bool openedAsRoute;

  const AddServicesPage({
    super.key,
    required this.businessId,
    this.services,
    this.title = "Add Service",
    this.sectionTitle = "Select Service Type",
    this.fallbackIcon = LucideIcons.stethoscope,
    this.openedAsRoute = false,
  });

  // ✅ لیست کامل
  static const List<String> _allServices = [
    'General Check-up',
    'Vaccination',
    'Laboratory',
    'X-ray',
    'Ultrasound',
    'Surgery',
    'Neutering',
    'Dental Care',
    'Emergency',
    'Hospitalization',
    'Microchip',
    'Home Visit',
    'Online Consultation',
  ];

  // ✅ آیکون‌ها
  static const Map<String, IconData> _icons = {
    'General Check-up': LucideIcons.activity,
    'Vaccination': LucideIcons.shieldCheck,
    'Laboratory': LucideIcons.flaskConical,
    'X-ray': LucideIcons.scanLine,
    'Ultrasound': LucideIcons.radio,
    'Surgery': LucideIcons.scissors,
    'Neutering': LucideIcons.circleDot,
    'Dental Care': LucideIcons.smile,
    'Emergency': LucideIcons.siren,
    'Hospitalization': LucideIcons.bed,
    'Microchip': LucideIcons.cpu,
    'Home Visit': LucideIcons.home,
    'Online Consultation': LucideIcons.video,
  };

  @override
  Widget build(BuildContext context) {
    final allServices = services ?? _allServices;

    return Material(
      color: AppTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (openedAsRoute) {
                        Navigator.pop(context);
                      } else {
                        context.read<AppState>().closeBusinessSubPage();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(title, style: AppTheme.h2()),
                ],
              ),
            ),

            /// BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(sectionTitle, fallbackIcon),
                  const SizedBox(height: 12),

                  /// ✅ LOOP
                  ...allServices.map((service) {
                    return _serviceCard(
                      context,
                      service,
                      _icons[service] ?? fallbackIcon,
                    );
                  }),

                  const SizedBox(height: 20),

                  _addCustomServiceCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// HEADER
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(title, style: AppTheme.h2()),
      ],
    );
  }

  /// SERVICE CARD
  Widget _serviceCard(BuildContext context, String title, IconData icon) {
    final appState = context.watch<AppState>();

    final exists = appState.existingServices
        .map((e) => e.toLowerCase())
        .contains(title.toLowerCase());

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddServiceDetailPage(
              businessId: businessId,
              serviceTitle: title,
              openedAsRoute: true,
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(22),

          border: Border.all(
            color: exists
                ? AppTheme.card
                : Colors.black.withValues(alpha: 0.06),
            width: exists ? 2 : 1,
          ),

          boxShadow: AppTheme.cardShadow(opacity: 0.04),
        ),

        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,

              decoration: BoxDecoration(
                color: AppTheme.card.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),

              child: Icon(icon, size: 20, color: AppTheme.card),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.h3()),

                  const SizedBox(height: 4),

                  Text(
                    exists ? "Tap to edit service" : "Tap to add service",
                    style: AppTheme.caption(),
                  ),
                ],
              ),
            ),

            Icon(
              exists ? LucideIcons.pencil : LucideIcons.plus,
              color: AppTheme.card,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// CUSTOM
  Widget _addCustomServiceCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddServiceDetailPage(
              businessId: businessId,
              serviceTitle: "Custom Service",
              openedAsRoute: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.plusCircle),
            const SizedBox(width: 10),
            const Expanded(child: Text("Add custom service")),
            Text(
              "Create",
              style: AppTheme.body().copyWith(
                color: const Color(0xFF9E1B4F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
