import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_header.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_panel.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_status_pill.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_business_location_resolver.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_location_permission_service.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_taxi/pet_taxi_document_resubmission_panel.dart';

bool isPetTaxiAvailabilityEligible(Map<String, dynamic> businessData) {
  final sectorData = (businessData['sectorData'] as Map?)
      ?.cast<String, dynamic>();
  final taxi = (sectorData?['pet_taxi'] as Map?)?.cast<String, dynamic>();
  final compliance = (taxi?['compliance'] as Map?)?.cast<String, dynamic>();
  final verification = (businessData['verification'] as Map?)
      ?.cast<String, dynamic>();

  return businessData['status'] == 'approved' &&
      verification?['isVerified'] == true &&
      compliance?['status'] == 'approved' &&
      taxi?['isActive'] == true &&
      taxi?['published'] == true &&
      businessData['published'] == true;
}

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
  final _permissionService = const PetTaxiLocationPermissionService();

  @override
  void initState() {
    super.initState();
    final sectorData = Map<String, dynamic>.from(
      widget.businessData['sectorData'] ?? {},
    );

    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});
    final compliance = Map<String, dynamic>.from(taxi['compliance'] ?? {});

    _isAvailable =
        taxi['isAvailable'] == true &&
        isPetTaxiAvailabilityEligible(widget.businessData);
    PetTaxiBusinessLocationResolver.scheduleMigrationIfNeeded(
      businessId: widget.businessId,
      businessData: widget.businessData,
    );
    _availabilityDebug(
      'INIT isAvailable=$_isAvailable '
      'isActive=${taxi['isActive'] == true} '
      'published=${taxi['published'] == true && widget.businessData['published'] == true} '
      'complianceStatus=${_safeValue(compliance['status'])}',
    );
    _availabilityDebug(
      'LOCATION_SERVICE_INIT online=$_isAvailable subscriptionStarted=false',
    );
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
        final availabilityEligible = isPetTaxiAvailabilityEligible(
          widget.businessData,
        );
        final displayedAvailability = availabilityEligible && _isAvailable;
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
            DashboardHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.petTaxiOverview,
                    style: AppTheme.h2().copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DashboardStatusPill(
                    prefix: 'Driver',
                    label: displayedAvailability ? 'Online' : 'Offline',
                    active: displayedAvailability,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DashboardMetricGrid(
              items: [
                DashboardMetricData(
                  label: 'Pending',
                  value: pending.toString(),
                  icon: LucideIcons.clock3,
                ),
                DashboardMetricData(
                  label: 'Active',
                  value: active.toString(),
                  icon: LucideIcons.navigation,
                ),
                DashboardMetricData(
                  label: 'Done',
                  value: completed.toString(),
                  icon: LucideIcons.checkCircle2,
                ),
              ],
              columns: 3,
              compact: true,
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DashboardPanel(
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
                    Switch(
                      value: displayedAvailability,
                      onChanged: availabilityEligible
                          ? _toggleAvailability
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            if (!availabilityEligible)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                child: Text(
                  AppLocalizations.of(context)!.petTaxiAwaitingActivation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
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
            PetTaxiDocumentResubmissionPanel(
              businessId: widget.businessId,
              businessData: widget.businessData,
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    final sectorData = Map<String, dynamic>.from(
      widget.businessData['sectorData'] ?? {},
    );
    final taxi = Map<String, dynamic>.from(sectorData['pet_taxi'] ?? {});
    final compliance = Map<String, dynamic>.from(taxi['compliance'] ?? {});
    _availabilityDebug(
      'TOGGLE_REQUESTED requested=$value current=$_isAvailable',
    );
    _availabilityDebug(
      'ELIGIBILITY_STATE '
      'isActive=${taxi['isActive'] == true} '
      'published=${taxi['published'] == true && widget.businessData['published'] == true} '
      'complianceApproved=${compliance['status'] == 'approved'} '
      'businessApproved=${widget.businessData['status'] == 'approved'} '
      'verified=${(widget.businessData['verification'] as Map?)?['isVerified'] == true}',
    );

    if (!isPetTaxiAvailabilityEligible(widget.businessData)) {
      _availabilityDebug('TOGGLE_ABORTED reason=not_operationally_eligible');
      if (mounted) {
        setState(() {
          _isAvailable = false;
        });
      }
      return;
    }

    if (value) {
      _availabilityDebug('PERMISSION_CHECK_START');
      bool granted;
      try {
        granted = await _permissionService.ensureForegroundPermission(context);
      } catch (error) {
        _availabilityDebug(
          'TOGGLE_ABORTED reason=permission_check_error '
          'type=${error.runtimeType} sanitizedMessage=${_safeError(error)}',
        );
        rethrow;
      }
      _availabilityDebug('PERMISSION_CHECK_RESULT result=$granted');
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      final locationPermission = await Geolocator.checkPermission();
      _availabilityDebug('LOCATION_SERVICE_STATE enabled=$locationEnabled');
      _availabilityDebug(
        'LOCATION_PERMISSION_STATE status=${locationPermission.name}',
      );

      if (!granted) {
        _availabilityDebug('TOGGLE_ABORTED reason=permission_denied');
        _availabilityDebug('LOCAL_STATE_UPDATE value=false');
        if (mounted) {
          setState(() {
            _isAvailable = false;
          });
        }
        return;
      }
    }
    _availabilityDebug('LOCAL_STATE_UPDATE value=$value');
    setState(() {
      _isAvailable = value;
    });

    _availabilityDebug(
      'FIRESTORE_WRITE_START '
      'field=sectorData.pet_taxi.isAvailable value=$value',
    );
    try {
      await FirebaseFirestore.instance
          .collection("businesses")
          .doc(widget.businessId)
          .update({"sectorData.pet_taxi.isAvailable": value});
      _availabilityDebug('FIRESTORE_WRITE_SUCCESS value=$value');
    } catch (error) {
      _availabilityDebug(
        'FIRESTORE_WRITE_ERROR '
        'code=${_firebaseErrorCode(error)} '
        'type=${error.runtimeType} '
        'sanitizedMessage=${_safeError(error)}',
      );
      _availabilityDebug('TOGGLE_ABORTED reason=firestore_write_error');
      if (mounted) {
        setState(() {
          _isAvailable = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.petTaxiAvailabilityUpdateFailed,
            ),
          ),
        );
      }
      return;
    }

    if (value) {
      _startLocationUpdates();
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _availabilityDebug('LOCATION_STREAM_STOP');
    }
    _availabilityDebug('TOGGLE_COMPLETE finalValue=$_isAvailable');
  }

  Future<void> _startLocationUpdates() async {
    _availabilityDebug('LOCATION_STREAM_START');

    _positionSubscription?.cancel();
    _availabilityDebug('PERMISSION_CHECK_START source=location_stream');
    bool granted;
    try {
      granted = await _permissionService.ensureForegroundPermission(context);
    } catch (error) {
      _availabilityDebug(
        'TOGGLE_ABORTED reason=location_permission_error '
        'type=${error.runtimeType} sanitizedMessage=${_safeError(error)}',
      );
      rethrow;
    }
    _availabilityDebug(
      'PERMISSION_CHECK_RESULT result=$granted source=location_stream',
    );
    if (!granted) {
      _availabilityDebug('TOGGLE_ABORTED reason=location_permission_denied');
      _availabilityDebug('LOCAL_STATE_UPDATE value=false');
      if (mounted) {
        setState(() {
          _isAvailable = false;
        });
      }
      _availabilityDebug(
        'FIRESTORE_WRITE_START '
        'field=sectorData.pet_taxi.isAvailable value=false '
        'reason=location_permission_denied',
      );
      try {
        await FirebaseFirestore.instance
            .collection("businesses")
            .doc(widget.businessId)
            .update({"sectorData.pet_taxi.isAvailable": false});
        _availabilityDebug('FIRESTORE_WRITE_SUCCESS value=false');
      } catch (error) {
        _availabilityDebug(
          'FIRESTORE_WRITE_ERROR '
          'code=${_firebaseErrorCode(error)} '
          'type=${error.runtimeType} '
          'sanitizedMessage=${_safeError(error)}',
        );
        _availabilityDebug('TOGGLE_ABORTED reason=firestore_write_error');
        rethrow;
      }
      return;
    }

    final permission = await Geolocator.checkPermission();
    _availabilityDebug('LOCATION_PERMISSION_STATE status=${permission.name}');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _availabilityDebug('LOCATION_SERVICE_STATE enabled=$serviceEnabled');

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
                if (_lastLat == position.latitude &&
                    _lastLng == position.longitude) {
                  return;
                }

                _lastLat = position.latitude;
                _lastLng = position.longitude;

                try {
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
                } catch (error) {
                  _availabilityDebug(
                    'LOCATION_STREAM_ERROR '
                    'type=${error.runtimeType} '
                    'sanitizedMessage=${_safeError(error)}',
                  );
                  rethrow;
                }
              },
              onError: (error) {
                _availabilityDebug(
                  'LOCATION_STREAM_ERROR '
                  'type=${error.runtimeType} '
                  'sanitizedMessage=${_safeError(error)}',
                );
              },
            );
    _availabilityDebug('LOCATION_STREAM_STARTED');
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _availabilityDebug('LOCATION_STREAM_STOP reason=dispose');

    super.dispose();
  }

  void _availabilityDebug(String message) {
    if (kDebugMode) {
      debugPrint('[PetTaxiAvailability] $message');
    }
  }

  String _safeValue(Object? value) {
    final text = value?.toString() ?? 'null';
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  }

  String _firebaseErrorCode(Object error) {
    return error is FirebaseException ? _safeValue(error.code) : 'none';
  }

  String _safeError(Object error) {
    var text = error is FirebaseException
        ? (error.message ?? '')
        : error.toString();
    text = text.replaceAll(RegExp(r'https?://\S+'), '<redacted-url>');
    text = text.replaceAll(
      RegExp(r'\b(?:businesses|businesses_public|pet_taxi_bookings)[^\s,;)]*'),
      '<redacted-path>',
    );
    text = text.replaceAll(RegExp(r'\b[A-Za-z0-9_-]{16,}\b'), '<redacted>');
    return _safeValue(text.length > 160 ? text.substring(0, 160) : text);
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<String> lines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardPanel(
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
      ),
    );
  }
}
