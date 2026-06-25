import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';

class PetTaxiDashboardOverviewTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetTaxiDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetTaxiDashboardOverviewTab> createState() =>
      _PetTaxiDashboardOverviewTabState();
}

class _PetTaxiDashboardOverviewTabState
    extends State<PetTaxiDashboardOverviewTab> {
  bool _isAvailable = false;
  StreamSubscription<Position>? _positionSubscription;
  double? _lastLat;
  double? _lastLng;

  @override
  void initState() {
    super.initState();

    final sectorData = Map<String, dynamic>.from(
      widget.businessData['sectorData'] ?? {},
    );

    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});

    _isAvailable = taxi['isAvailable'] == true;
    debugPrint("🚀 INIT isAvailable = $_isAvailable");
    debugPrint("🚀 START LOCATION SERVICE");
    if (_isAvailable) {
      _startLocationUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectorData = Map<String, dynamic>.from(
      widget.businessData['sectorData'] ?? {},
    );
    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});
    final compliance = Map<String, dynamic>.from(taxi['compliance'] ?? {});
    final vehicle = Map<String, dynamic>.from(taxi['vehicle'] ?? {});
    final driver = Map<String, dynamic>.from(taxi['driver'] ?? {});

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pet_taxi_bookings')
          .where('businessId', isEqualTo: widget.businessId)
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
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.cardShadow(opacity: 0.05),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_taxi_rounded,
                    color: Color(0xFFFF4F9B),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Driver Online",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch(value: _isAvailable, onChanged: _toggleAvailability),
                ],
              ),
            ),

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
                'Status: ${compliance['status'] ?? widget.businessData['status'] ?? '-'}',
                'Safety equipment: ${compliance['petSafetyEquipmentConfirmed'] == true ? 'Confirmed' : '-'}',
                'Hygiene: ${compliance['hygieneSanitationConfirmed'] == true ? 'Confirmed' : '-'}',
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    debugPrint("🔘 SWITCH = $value");
    setState(() {
      _isAvailable = value;
    });

    await FirebaseFirestore.instance
        .collection("businesses")
        .doc(widget.businessId)
        .update({"sectorData.pet_taxi.isAvailable": value});

    if (value) {
      _startLocationUpdates();
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }
  }

  Future<void> _startLocationUpdates() async {
    debugPrint("🚀 _startLocationUpdates CALLED");

    _positionSubscription?.cancel();

    final permission = await Geolocator.checkPermission();

    debugPrint("📍 PERMISSION = $permission");

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    debugPrint("📍 LOCATION SERVICE = $serviceEnabled");

    _positionSubscription =
        Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 50,
              ),
            )
            .distinct(
              (previous, current) =>
                  previous.latitude == current.latitude &&
                  previous.longitude == current.longitude,
            )
            .listen(
              (position) async {
                debugPrint("🔥 LOCATION STREAM EVENT");

                debugPrint(
                  "📍 NEW POSITION = "
                  "${position.latitude}, ${position.longitude}",
                );

                if (_lastLat == position.latitude &&
                    _lastLng == position.longitude) {
                  debugPrint("⏭️ SAME LOCATION -> SKIPPED");
                  return;
                }

                _lastLat = position.latitude;
                _lastLng = position.longitude;

                debugPrint(
                  "📍 FIRESTORE WRITE -> "
                  "${position.latitude}, ${position.longitude}",
                );

                await FirebaseFirestore.instance
                    .collection("businesses")
                    .doc(widget.businessId)
                    .update({
                      "sectorData.pet_taxi.currentLocation.lat":
                          position.latitude,
                      "sectorData.pet_taxi.currentLocation.lng":
                          position.longitude,
                      "sectorData.pet_taxi.currentLocation.updatedAt":
                          FieldValue.serverTimestamp(),
                    });

                debugPrint(
                  "🚕 DRIVER LOCATION UPDATED -> "
                  "${position.latitude}, ${position.longitude}",
                );
              },
              onError: (error) {
                debugPrint("❌ POSITION STREAM ERROR = $error");
              },
            );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();

    super.dispose();
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
