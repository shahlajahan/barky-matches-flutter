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
    //debugPrint('📍 Dashboard parent build ${identityHashCode(this)}');
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
    final sector = _resolveBusinessSector(sectors, data);

    /// 🐶 VET
    if (sector == 'vet') {
      return KeyedSubtree(
        key: ValueKey(widget.businessId),
        child: VetDashboardPage(
          businessId: widget.businessId,
          businessData: data,
        ),
      );
    }

    if (sector == 'pet_shop') {
      return const PetShopDashboardPage();
    }

    if (sector == 'groomy') {
      debugPrint(
        "GROOMY CHILD BUILD "
        "dataHash=${identityHashCode(data)}",
      );
      return GroomyDashboardPage(
        key: ValueKey(widget.businessId),

        businessId: widget.businessId,

        businessData: data,
      );
    }

    if (sector == 'adoption_center') {
      return AdoptionCenterDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );
    }

    if (sector == 'pet_hotel') {
      return PetHotelDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );
    }

    if (sector == 'pet_taxi') {
      return PetTaxiDashboardPage(
        businessId: widget.businessId,
        businessData: data,
      );
    }

    return _EmptyView(
      message: l10n.sectorDashboardNotImplementedYet,
      onBack: () => context.read<AppState>().closeProfileSubPage(),
    );
  }

  String _resolveBusinessSector(
    List<String> sectors,
    Map<String, dynamic> data,
  ) {
    final sectorData =
        (data['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};
    final normalized = [
      ...sectors,
      ...sectorData.keys,
      data['sector'],
      data['type'],
      data['businessType'],
      data['category'],
    ].map((value) => value?.toString().trim().toLowerCase() ?? '').toList();

    bool hasAny(List<String> values) {
      return normalized.any((item) => values.any(item.contains));
    }

    if (sectorData.containsKey('adoption_center') ||
        sectorData.containsKey('adoptionCenter') ||
        hasAny(['adoption_center', 'adoption center', 'adoptioncenter']) ||
        normalized.any((item) => item == 'adoption')) {
      return 'adoption_center';
    }

    if (sectorData.containsKey('pet_taxi') ||
        hasAny(['pet_taxi', 'pet taxi']) ||
        normalized.any((item) => item == 'taxi')) {
      return 'pet_taxi';
    }

    if (sectorData.containsKey('pet_hotel') ||
        sectorData.containsKey('hotel') ||
        sectorData.containsKey('petHotel') ||
        hasAny(['pet_hotel', 'pet hotel', 'boarding']) ||
        normalized.any((item) => item == 'hotel')) {
      return 'pet_hotel';
    }

    if (sectorData.containsKey('groomy') ||
        sectorData.containsKey('grooming') ||
        sectorData.containsKey('groomer') ||
        hasAny(['groomy', 'grooming', 'groomer'])) {
      return 'groomy';
    }

    if (sectorData.containsKey('pet_shop') ||
        sectorData.containsKey('petshop') ||
        hasAny(['pet_shop', 'pet shop', 'petshop', 'seller', 'store'])) {
      return 'pet_shop';
    }

    if (sectorData.containsKey('veterinary') ||
        sectorData.containsKey('vet') ||
        hasAny(['veterinary']) ||
        normalized.any((item) => item == 'vet')) {
      return 'vet';
    }

    return 'empty';
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
