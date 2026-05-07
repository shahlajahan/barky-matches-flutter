import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_dashboard_page.dart';

class BusinessDashboardPage extends StatelessWidget {
  final String businessId;

  const BusinessDashboardPage({
    super.key,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          /// =============================
          /// ❌ ERROR
          /// =============================
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Something went wrong',
              onBack: () =>
                  context.read<AppState>().closeProfileSubPage(),
            );
          }

          /// =============================
          /// ❌ NOT FOUND
          /// =============================
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _EmptyView(
              message: 'Business not found',
              onBack: () =>
                  context.read<AppState>().closeProfileSubPage(),
            );
          }

          /// =============================
          /// ✅ DATA READY
          /// =============================
          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final sectors =
              List<String>.from(data['sectors'] ?? []);

          /// =============================
          /// 🐾 ROUTING BY SECTOR
          /// =============================
          return _buildDashboardBySector(
            context,
            sectors,
            data,
          );
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
    /// 🐶 VET
    if (sectors.contains('veterinary')) {
      return VetDashboardPage(
        businessId: businessId,
        businessData: data,
      );
    }

    /// 🔜 FUTURE SECTORS
    /// petshop, groomer, hotel, etc...

    return _EmptyView(
      message: 'This sector dashboard is not implemented yet',
      onBack: () =>
          context.read<AppState>().closeProfileSubPage(),
    );
  }
}

/// =============================
/// ❌ ERROR VIEW
/// =============================
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorView({
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseStateView(
      icon: Icons.error_outline,
      message: message,
      buttonText: 'Go Back',
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

  const _EmptyView({
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseStateView(
      icon: Icons.info_outline,
      message: message,
      buttonText: 'Back',
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
            Icon(
              icon,
              size: 48,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.body(
                color: AppTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}