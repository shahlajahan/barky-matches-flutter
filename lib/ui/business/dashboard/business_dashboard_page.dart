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

class BusinessDashboardPage extends StatelessWidget {
  final String businessId;

  const BusinessDashboardPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppTheme.bg,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .snapshots(),
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
    final sectorData =
        (data['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};
    final normalizedSectors = {
      ...sectors.map((sector) => sector.toLowerCase()),
      ...sectorData.keys.map((sector) => sector.toLowerCase()),
    };

    final hasPetShop =
        normalizedSectors.contains('pet_shop') ||
        normalizedSectors.contains('petshop');

    final hasGrooming =
        normalizedSectors.contains('grooming') ||
        normalizedSectors.contains('groomer') ||
        ((data['sectorData']?['petshop']?['shopTypes'] as List?)?.contains(
              'Grooming',
            ) ??
            false);

    /// 🐶 VET
    if (normalizedSectors.contains('veterinary')) {
      return VetDashboardPage(businessId: businessId, businessData: data);
    }

    if (hasPetShop && hasGrooming) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Pet Shop'),
                Tab(text: 'Groomy'),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  const PetShopDashboardPage(),

                  GroomyDashboardPage(
                    businessId: businessId,
                    businessData: data,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasGrooming) {
      return GroomyDashboardPage(businessId: businessId, businessData: data);
    }

    if (normalizedSectors.contains('adoption_center') ||
        normalizedSectors.contains('adoption') ||
        normalizedSectors.contains('adoptioncenter')) {
      return AdoptionCenterDashboardPage(
        businessId: businessId,
        businessData: data,
      );
    }

    if (normalizedSectors.contains('pet_hotel') ||
        normalizedSectors.contains('hotel') ||
        normalizedSectors.contains('pet hotel')) {
      return PetHotelDashboardPage(businessId: businessId, businessData: data);
    }

    if (normalizedSectors.contains('pet_taxi') ||
        normalizedSectors.contains('pet taxi') ||
        normalizedSectors.contains('taxi')) {
      return PetTaxiDashboardPage(businessId: businessId, businessData: data);
    }

    return _EmptyView(
      message: l10n.sectorDashboardNotImplementedYet,
      onBack: () => context.read<AppState>().closeProfileSubPage(),
    );
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
