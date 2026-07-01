import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_hotel/pet_hotel_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/pet_taxi_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/adoption_center_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_dashboard_page.dart';


enum BusinessSector {
  vet,
  petShop,
  groomy,
  petHotel,
  petTaxi,
  adoptionCenter,
}

class BusinessDashboardPage extends StatefulWidget {
  final String businessId;

  const BusinessDashboardPage({super.key, required this.businessId});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  late final Stream<DocumentSnapshot> _businessStream;

  @override
  void initState() {
    super.initState();
    //debugPrint('🏢 BusinessDashboardPage initState ${identityHashCode(this)}');
    _businessStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .snapshots();
  }

  @override
  void didUpdateWidget(covariant BusinessDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    debugPrint(
      "🏢 BusinessDashboardPage didUpdateWidget "
      "oldHash=${identityHashCode(oldWidget)} "
      "newHash=${identityHashCode(widget)} "
      "sameBusiness=${oldWidget.businessId == widget.businessId}",
    );
  }

  @override
  void deactivate() {
    debugPrint('🏢 BusinessDashboardPage deactivate ${identityHashCode(this)}');
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    debugPrint('🏢 BusinessDashboardPage activate ${identityHashCode(this)}');
  }

  @override
  void dispose() {
    debugPrint('🏢 BusinessDashboardPage dispose ${identityHashCode(this)}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔥 BusinessDashboardPage BUILD");

    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppTheme.bg,
      child: StreamBuilder<DocumentSnapshot>(
        stream: _businessStream,
        builder: (context, snapshot) {
          /// =============================
          /// ⏳ LOADING
          /// =============================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          /// =============================
          /// ❌ ERROR
          /// =============================
          if (snapshot.hasError) {
            return _ErrorView(
              message: l10n.somethingWentWrong,
              onBack: () => context.read<AppState>().closeProfileSubPage(),
            );
          }

          /// =============================
          /// ❌ NOT FOUND
          /// =============================
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _EmptyView(
              message: l10n.businessNotFound,
              onBack: () => context.read<AppState>().closeProfileSubPage(),
            );
          }

          /// =============================
          /// ✅ DATA READY
          /// =============================
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final sectors = List<String>.from(data['sectors'] ?? []);

          /// =============================
          /// 🐾 ROUTING BY SECTOR
          /// =============================
          return _buildDashboardBySector(context, sectors, data);
        },
      ),
    );
  }

  /// =============================
  /// 🎯 SECTOR ROUTER
  /// =============================
  Widget _buildDashboardBySector(
    BuildContext context,
    List<String> sectors,
    Map<String, dynamic> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final available = _resolveBusinessSectors(sectors, data);

    if (available.isEmpty) {
  return _EmptyView(
    message: l10n.sectorDashboardNotImplementedYet,
    onBack: () => context.read<AppState>().closeProfileSubPage(),
  );
}

if (available.length == 1) {
  return _buildSingleDashboard(
    context,
    available.first,
    data,
  );
}

return DefaultTabController(
  length: available.length,
  child: Column(
    children: [
      Material(
        color: Colors.white,
        child: TabBar(
          isScrollable: true,
          tabs: available.map((sector) {
            return Tab(text: _sectorTitle(sector));
          }).toList(),
        ),
      ),
      Expanded(
        child: TabBarView(
          children: available.map((sector) {
            return _buildSingleDashboard(
              context,
              sector,
              data,
            );
          }).toList(),
        ),
      ),
    ],
  ),
);

    /// 🐶 VET
    
  }

  List<BusinessSector> _resolveBusinessSectors(
  List<String> sectors,
  Map<String, dynamic> data,
) {
  final result = <BusinessSector>{};

  final sectorData =
      (data['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};

  final normalized = [
    ...sectors,
    ...sectorData.keys,
    data['sector'],
    data['type'],
    data['businessType'],
    data['category'],
  ]
      .map((e) => e?.toString().trim().toLowerCase() ?? '')
      .toList();

  bool hasAny(List<String> values) {
    return normalized.any((item) => values.any(item.contains));
  }

  if (sectorData.containsKey('vet') ||
      sectorData.containsKey('veterinary') ||
      hasAny(['vet', 'veterinary'])) {
    result.add(BusinessSector.vet);
  }

  if (sectorData.containsKey('petshop') ||
      sectorData.containsKey('pet_shop') ||
      hasAny(['pet_shop', 'petshop', 'pet shop', 'store'])) {
    result.add(BusinessSector.petShop);
  }

  if (sectorData.containsKey('groomy') ||
      sectorData.containsKey('grooming') ||
      hasAny(['groomy', 'groomer', 'grooming'])) {
    result.add(BusinessSector.groomy);
  }

  if (sectorData.containsKey('pet_hotel') ||
      sectorData.containsKey('hotel') ||
      hasAny(['pet_hotel', 'pet hotel'])) {
    result.add(BusinessSector.petHotel);
  }

  if (sectorData.containsKey('pet_taxi') ||
      hasAny(['pet_taxi', 'pet taxi'])) {
    result.add(BusinessSector.petTaxi);
  }

  if (sectorData.containsKey('adoption_center') ||
      hasAny(['adoption_center', 'adoption center'])) {
    result.add(BusinessSector.adoptionCenter);
  }

  return result.toList();
}

Widget _buildSingleDashboard(
  BuildContext context,
  BusinessSector sector,
  Map<String, dynamic> data,
) {
  switch (sector) {
    case BusinessSector.vet:
      return VetDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );

    case BusinessSector.petShop:
      return const PetShopDashboardPage();

    case BusinessSector.groomy:
      return GroomyDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );

    case BusinessSector.petHotel:
      return PetHotelDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );

    case BusinessSector.petTaxi:
      return PetTaxiDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );

    case BusinessSector.adoptionCenter:
      return AdoptionCenterDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );
  }
}

String _sectorTitle(BusinessSector sector) {
  switch (sector) {
    case BusinessSector.vet:
      return "Veterinary";

    case BusinessSector.petShop:
      return "Pet Shop";

    case BusinessSector.groomy:
      return "Grooming";

    case BusinessSector.petHotel:
      return "Pet Hotel";

    case BusinessSector.petTaxi:
      return "Pet Taxi";

    case BusinessSector.adoptionCenter:
      return "Adoption";
  }
}

}

/// =============================
/// ❌ ERROR VIEW
/// =============================
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _BaseStateView(
      icon: Icons.error_outline,
      message: message,
      buttonText: l10n.goBackButton,
      onPressed: onBack,
    );
  }
}

/// =============================
/// 📭 EMPTY VIEW
/// =============================
class _EmptyView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _EmptyView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _BaseStateView(
      icon: Icons.info_outline,
      message: message,
      buttonText: l10n.backButton,
      onPressed: onBack,
    );
  }
}

/// =============================
/// 🎨 BASE STATE VIEW
/// =============================
class _BaseStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _BaseStateView({
    required this.icon,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.body(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}
