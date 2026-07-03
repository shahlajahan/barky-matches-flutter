import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_driver_location_resolver.dart';

class LiveTripStatusCard extends StatelessWidget {
  final String businessId;
  final String bookingStatus;

  const LiveTripStatusCard({
    super.key,
    required this.businessId,
    required this.bookingStatus,
  });

  static const _visibleStatuses = [
    'confirmed_paid',
    'driver_on_the_way',
    'arrived',
    'pet_picked_up',
    'on_trip',
    'completed',
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint("🚕 LIVE CARD BUILD");
    if (!_visibleStatuses.contains(bookingStatus)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() ?? {};

        final sectorData = _map(data['sectorData']);
        final contact = _map(data['contact']);

        final taxi = _map(
          sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
        );

        final driver = _map(taxi['driver']);
        final vehicle = _map(taxi['vehicle']);
        final location = PetTaxiDriverLocationResolver.resolveDisplayLocation(
          taxi: taxi,
          contact: contact,
        );
        final lat = location?.lat;
        final lng = location?.lng;
        final updatedAt = location?.updatedAt;

        debugPrint("🚕 LIVE TRIP STREAM -> $businessId");

        debugPrint("📍 LIVE DRIVER POSITION -> $lat , $lng");
        debugPrint(
          "📍 LIVE DRIVER LOCATION SOURCE -> ${location?.source.name}",
        );

        debugPrint("👤 LIVE DRIVER NAME -> ${driver['fullName']}");

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFF4F9B).withOpacity(.15)),
            boxShadow: AppTheme.cardShadow(opacity: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4F9B).withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.car,
                      color: Color(0xFFFF4F9B),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Live Driver",
                          style: AppTheme.bodyMedium().copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          driver['fullName']?.toString() ?? "Driver",
                          style: AppTheme.body(color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      bookingStatus.replaceAll("_", " ").toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _item(LucideIcons.user, "Driver", driver['fullName']),

              _item(LucideIcons.badge, "Plate", vehicle['plateNumber']),

              _item(
                LucideIcons.mapPin,
                "Latitude",
                lat?.toStringAsFixed(6) ?? "-",
              ),

              _item(
                LucideIcons.navigation,
                "Longitude",
                lng?.toStringAsFixed(6) ?? "-",
              ),

              _item(
                LucideIcons.clock3,
                "Last Update",
                _formatUpdatedAt(updatedAt),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _item(IconData icon, String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF9E1B4F)),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.caption(color: AppTheme.muted)),

                const SizedBox(height: 2),

                Text(value?.toString() ?? "-", style: AppTheme.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdatedAt(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    }

    if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return "-";
    }

    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    return <String, dynamic>{};
  }
}
