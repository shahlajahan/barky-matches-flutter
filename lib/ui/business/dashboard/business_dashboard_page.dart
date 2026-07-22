import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_web_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_hotel/pet_hotel_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_hotel/pet_hotel_web_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/pet_taxi_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/pet_taxi_web_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/adoption_center/adoption_center_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_web_dashboard_page.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_web_dashboard_page.dart';

enum BusinessSector { vet, petShop, groomy, petHotel, petTaxi, adoptionCenter }

String _normalizeSectorIdentifier(Object? value) =>
    value?.toString().trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_') ??
    '';

/// Resolves dashboard sectors from the canonical business schema.
///
/// New business documents always persist an explicit `sectors` array. When
/// that array contains at least one value it is authoritative: `sectorData`
/// contains configuration payloads and may retain stale keys. Exact legacy
/// fields are consulted only for older documents without an explicit sector
/// list.
List<BusinessSector> resolveBusinessDashboardSectors(
  List<Object?> sectors,
  Map<String, dynamic> data,
) {
  final explicit = sectors
      .map(_normalizeSectorIdentifier)
      .where((value) => value.isNotEmpty)
      .toList();
  final identifiers = <String>{};

  if (explicit.isNotEmpty) {
    identifiers.addAll(explicit);
  } else {
    final sectorData = (data['sectorData'] as Map?) ?? const {};
    identifiers.addAll(
      sectorData.keys
          .map(_normalizeSectorIdentifier)
          .where((value) => value.isNotEmpty),
    );
    identifiers.addAll(
      [
        data['sector'],
        data['type'],
        data['businessType'],
        data['category'],
      ].map(_normalizeSectorIdentifier).where((value) => value.isNotEmpty),
    );
  }

  const aliases = <String, BusinessSector>{
    'vet': BusinessSector.vet,
    'veterinary': BusinessSector.vet,
    'veterinarian': BusinessSector.vet,
    'petshop': BusinessSector.petShop,
    'pet_shop': BusinessSector.petShop,
    'store': BusinessSector.petShop,
    'groomy': BusinessSector.groomy,
    'groomer': BusinessSector.groomy,
    'grooming': BusinessSector.groomy,
    'pet_hotel': BusinessSector.petHotel,
    'pethotel': BusinessSector.petHotel,
    'hotel': BusinessSector.petHotel,
    'pet_taxi': BusinessSector.petTaxi,
    'pettaxi': BusinessSector.petTaxi,
    'adoption': BusinessSector.adoptionCenter,
    'adoption_center': BusinessSector.adoptionCenter,
    'adoptioncenter': BusinessSector.adoptionCenter,
  };

  final result = <BusinessSector>[];
  for (final identifier in identifiers) {
    final sector = aliases[identifier];
    if (sector != null && !result.contains(sector)) result.add(sector);
  }
  return result;
}

class BusinessDashboardPage extends StatefulWidget {
  final String businessId;

  const BusinessDashboardPage({super.key, required this.businessId});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  late Stream<DocumentSnapshot> _businessStream;

  @override
  void initState() {
    super.initState();
    //debugPrint('🏢 BusinessDashboardPage initState ${identityHashCode(this)}');
    _bindBusinessStream();
  }

  void _bindBusinessStream() {
    _businessStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .snapshots();
  }

  @override
  void didUpdateWidget(covariant BusinessDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.businessId != widget.businessId) {
      _bindBusinessStream();
    }

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
    final available = resolveBusinessDashboardSectors(sectors, data);

    if (available.isEmpty) {
      return _EmptyView(
        message: l10n.sectorDashboardNotImplementedYet,
        onBack: () => context.read<AppState>().closeProfileSubPage(),
      );
    }

    if (available.length == 1) {
      return _buildSingleDashboard(context, available.first, data);
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
                return _buildSingleDashboard(context, sector, data);
              }).toList(),
            ),
          ),
        ],
      ),
    );

    /// 🐶 VET
  }

  Widget _buildSingleDashboard(
    BuildContext context,
    BusinessSector sector,
    Map<String, dynamic> data,
  ) {
    final isDesktopWeb = kIsWeb && MediaQuery.sizeOf(context).width >= 1100;

    switch (sector) {
      case BusinessSector.vet:
        if (isDesktopWeb) {
          return VetWebDashboardPage(
            businessId: widget.businessId,
            businessData: data,
          );
        }

        return VetDashboardPage(
          businessId: widget.businessId,
          businessData: data,
        );

      case BusinessSector.petShop:
        if (isDesktopWeb) {
          return PetShopWebDashboardPage(
            businessId: widget.businessId,
            businessData: data,
          );
        }
        return const PetShopDashboardPage();

      case BusinessSector.groomy:
        if (isDesktopWeb) {
          return GroomyWebDashboardPage(
            businessId: widget.businessId,
            businessData: data,
          );
        }
        return GroomyDashboardPage(
          businessId: widget.businessId,
          businessData: data,
        );

      case BusinessSector.petHotel:
        if (isDesktopWeb) {
          return PetHotelWebDashboardPage(
            businessId: widget.businessId,
            businessData: data,
          );
        }
        return PetHotelDashboardPage(
          businessId: widget.businessId,
          businessData: data,
        );

      case BusinessSector.petTaxi:
        if (isDesktopWeb) {
          return PetTaxiWebDashboardPage(
            businessId: widget.businessId,
            businessData: data,
          );
        }
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
