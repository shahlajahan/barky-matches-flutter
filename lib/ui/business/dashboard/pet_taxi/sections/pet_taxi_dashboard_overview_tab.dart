import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_business_location_resolver.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_location_permission_service.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _revenueStream;
  StreamSubscription<Position>? _positionSubscription;
  double? _lastLat;
  double? _lastLng;
  final _permissionService = const PetTaxiLocationPermissionService();

  @override
  void initState() {
    super.initState();
    _revenueStream = FirebaseFirestore.instance
        .collection('pet_taxi_bookings')
        .where('businessId', isEqualTo: widget.businessId)
        .snapshots(includeMetadataChanges: false);
    final sectorData = Map<String, dynamic>.from(
      widget.businessData['sectorData'] ?? {},
    );

    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});

    _isAvailable = taxi['isAvailable'] == true;
    PetTaxiBusinessLocationResolver.scheduleMigrationIfNeeded(
      businessId: widget.businessId,
      businessData: widget.businessData,
    );
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
              AppLocalizations.of(context)!.petTaxiOverview,
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
            const SizedBox(height: 16),
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
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.driverOnline,
                      style: const TextStyle(
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
    if (value) {
      final granted = await _permissionService.ensureForegroundPermission(
        context,
      );
      if (!granted) {
        if (mounted) {
          setState(() {
            _isAvailable = false;
          });
        }
        return;
      }
    }
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
    final granted = await _permissionService.ensureForegroundPermission(
      context,
    );
    if (!granted) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
        });
      }
      await FirebaseFirestore.instance
          .collection("businesses")
          .doc(widget.businessId)
          .update({"sectorData.pet_taxi.isAvailable": false});
      return;
    }

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
                      "sectorData.pet_taxi.currentLocation.source":
                          "gps_runtime",
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

  Widget _buildRevenueCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _revenueStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        final paidDocs = docs.where((doc) {
          final status = (doc.data()['status'] ?? '').toString().toLowerCase();

          return const {
            'confirmed_paid',
            'pet_picked_up',
            'on_trip',
            'completed',
          }.contains(status);
        }).toList();

        if (paidDocs.isEmpty) {
          return _infoCard(
            title: 'Revenue',
            icon: LucideIcons.wallet,
            lines: ['No revenue yet'],
          );
        }

        double grossSales = 0;
        double commission = 0;
        double netRevenue = 0;

        for (final doc in paidDocs) {
          final data = doc.data();
          debugPrint("🚕 BOOKING ${doc.id}");
          debugPrint(data.toString());
          debugPrint("STATUS = ${data['status']}");
          debugPrint("BOOKING STATUS = ${data['bookingStatus']}");
          debugPrint("LIFECYCLE = ${data['lifecycleStatus']}");
          final financial = Map<String, dynamic>.from(data['financial'] ?? {});

          final pricing = Map<String, dynamic>.from(data['pricing'] ?? {});

          final gross = _moneyValue(
            pricing['grandTotal'] ?? pricing['subtotal'] ?? data['finalPrice'],
          );

          final fee = _moneyValue(
            financial['platformCommissionAmount'] ??
                financial['commissionAmount'],
          );

          final net = _moneyValue(
            financial['businessNetAmount'] ?? gross - fee,
          );

          grossSales += gross;
          commission += fee;
          netRevenue += net;
        }

        final average = paidDocs.isEmpty ? 0 : grossSales / paidDocs.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.vetRevenueNetRevenue,
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              Text(
                "₺${netRevenue.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              _revenueRow("Gross Sales", grossSales),
              _revenueRow("Platform Fee", -commission),
              _revenueRow("Adjustments", 0),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _miniRevenue(
                      "Completed Trips",
                      paidDocs.length.toString(),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _miniRevenue(
                      "Average Trip",
                      "₺${average.toStringAsFixed(0)}",
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _revenueRow(String title, double value) {
    final negative = value < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),

          Text(
            "${negative ? "-" : ""}₺${value.abs().toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _miniRevenue(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 4),

          Text(title, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  double _moneyValue(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
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
