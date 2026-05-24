import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetTaxiDashboardOverviewTab extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetTaxiDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  Widget build(BuildContext context) {
    final sectorData = Map<String, dynamic>.from(
      businessData['sectorData'] ?? {},
    );
    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});
    final compliance = Map<String, dynamic>.from(taxi['compliance'] ?? {});
    final vehicle = Map<String, dynamic>.from(taxi['vehicle'] ?? {});
    final driver = Map<String, dynamic>.from(taxi['driver'] ?? {});

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pet_taxi_bookings')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pending = docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length;
        final active = docs.where((doc) {
          final status = doc.data()['status']?.toString() ?? '';
          return const [
            'accepted',
            'driver_on_the_way',
            'arrived',
            'pet_picked_up',
            'on_trip',
          ].contains(status);
        }).length;
        final completed = docs
            .where((doc) => doc.data()['status'] == 'completed')
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Pet Taxi Overview',
              style: AppTheme.h2().copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _stat('Pending', pending, Colors.orange)),
                const SizedBox(width: 10),
                Expanded(child: _stat('Active', active, Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _stat('Done', completed, Colors.green)),
              ],
            ),
            const SizedBox(height: 14),
            _infoCard(
              title: 'Vehicle',
              icon: LucideIcons.car,
              lines: [
                'Plate: ${vehicle['plateNumber'] ?? '-'}',
                'Type: ${vehicle['vehicleType'] ?? '-'}',
                'Capacity: ${vehicle['capacity'] ?? '-'}',
              ],
            ),
            _infoCard(
              title: 'Driver',
              icon: LucideIcons.user,
              lines: [
                'Name: ${driver['fullName'] ?? '-'}',
                'Phone: ${driver['phoneNumber'] ?? '-'}',
              ],
            ),
            _infoCard(
              title: 'Compliance',
              icon: LucideIcons.shieldCheck,
              lines: [
                'Manual review: ${compliance['manualReviewRequired'] == true ? 'Required' : '-'}',
                'Status: ${compliance['status'] ?? businessData['status'] ?? '-'}',
                'Safety equipment: ${compliance['petSafetyEquipmentConfirmed'] == true ? 'Confirmed' : '-'}',
                'Hygiene: ${compliance['hygieneSanitationConfirmed'] == true ? 'Confirmed' : '-'}',
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.caption(color: AppTheme.muted)),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<String> lines,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF9E1B4F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: AppTheme.body(color: AppTheme.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.05),
    );
  }
}
