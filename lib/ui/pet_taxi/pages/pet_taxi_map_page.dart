import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barky_matches_fixed/core/debug/google_map_health_monitor.dart';

import '../services/pet_taxi_business_location_resolver.dart';
import '../services/pet_taxi_location_permission_service.dart';
import '../widgets/current_location_button.dart';
import '../widgets/pet_taxi_bottom_sheet.dart';
import '../pet_taxi_driver_location_resolver.dart';
import 'package:barky_matches_fixed/debug/firestore_query_trace.dart';

class PetTaxiMapPage extends StatefulWidget {
  const PetTaxiMapPage({super.key});

  @override
  State<PetTaxiMapPage> createState() => _PetTaxiMapPageState();
}

class _PetTaxiMapPageState extends State<PetTaxiMapPage>
    with GoogleMapHealthMonitor<PetTaxiMapPage> {
  static const CameraPosition _fallbackCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 11,
  );

  CameraPosition? _initialCameraPosition;
  GoogleMapController? _mapController;
  bool _cameraMoved = false;
  bool _firstSuccessfulCameraMovementTracked = false;
  bool _myLocationEnabled = false;
  LatLng? _firstDriverPosition;
  Set<Marker> _markers = const {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driversSubscription;
  BitmapDescriptor? _driverMarker;
  final _permissionService = const PetTaxiLocationPermissionService();
  bool _pageReady = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
    final query = FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'approved');
    FirestoreQueryTrace.log(
      file: 'lib/ui/pet_taxi/pages/pet_taxi_map_page.dart',
      method: '_driversStream',
      line: 45,
      collection: 'businesses',
      clauses: const ["where(status, isEqualTo: approved)"],
      terminalCall: 'snapshots()',
      query: query,
    );
    return query.snapshots();
  }

  @override
  void initState() {
    super.initState();
    startGoogleMapHealthTimer(
      feature: 'pet_taxi_map',
      data: <String, dynamic>{
        'page': 'PetTaxiMapPage',
      },
    );
    _initializePage();
  }

 Future<void> _initializePage() async {
  try {
    await _initializeMyLocation();

    if (!mounted) return;

    await _loadDriverMarker();

    if (!mounted) return;

    _driversSubscription =
        _driversStream().listen(_handleDriversSnapshot);
  } catch (e, stackTrace) {
    debugPrint('PetTaxi initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    if (!mounted) return;

    setState(() {
      _pageReady = true;
    });
  }
}

  Future<void> _initializeMyLocation() async {


  if (!mounted) {
    debugPrint("❌ Widget not mounted");
    return;
  }

  final granted =
      await _permissionService.ensureForegroundPermission(context);

  

  if (!mounted) {
    debugPrint("❌ Widget unmounted after permission");
    return;
  }

  setState(() {
    _myLocationEnabled = granted;
  });

 
}

  @override
  void dispose() {
    cancelGoogleMapHealthTimer();
    _driversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

 Future<void> _loadDriverMarker() async {
  try {
    _driverMarker = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(56, 56)),
      'assets/taxi_marker.png',
    );
  } catch (e, stackTrace) {
    debugPrint("❌ TAXI MARKER LOAD FAILED = $e");
    debugPrintStack(stackTrace: stackTrace);

    _driverMarker = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRose,
    );
  }

  if (mounted) {
    setState(() {});
  }
}

  Future<void> _moveCameraToUser() async {
    final granted = await _permissionService.ensureForegroundPermission(context);
    if (!mounted || !granted) {
      return;
    }

    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    setState(() {
      _myLocationEnabled = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
      _markMapReadyFromSuccessfulCameraMovement(
        trigger: 'userLocation',
        data: <String, dynamic>{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'zoom': 16,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('User GPS error = $e');
      await reportMapInitializationFailure(
        error: e,
        stackTrace: stackTrace,
        message: 'Pet Taxi map initialization failed while focusing user location',
        data: <String, dynamic>{
          'page': 'PetTaxiMapPage',
          'stage': 'focusUserLocation',
        },
      );
    }
  }

  void _handleDriversSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
  debugPrint(
    'PET_TAXI_DRIVERS_SNAPSHOT fromCache=${snapshot.metadata.isFromCache} '
    'docs=${snapshot.docs.length}',
  );
  final markers = <Marker>{};

  for (final doc in snapshot.docs) {
    final data = {...doc.data(), 'id': doc.id};

    PetTaxiBusinessLocationResolver.scheduleMigrationIfNeeded(
      businessId: doc.id,
      businessData: data,
    );

    final sectorData = _map(data['sectorData']);
    final taxi = _map(
      sectorData['pet_taxi'] ??
          sectorData['petTaxi'] ??
          sectorData['taxi'],
    );

    if (taxi['isAvailable'] != true) {
      continue;
    }

    final contact = _map(data['contact']);

    final location = PetTaxiDriverLocationResolver.resolveDisplayLocation(
      taxi: taxi,
      contact: contact,
    );

    debugPrint("🚕 DRIVER = ${_businessName(data, taxi)}");
    debugPrint("🚕 AVAILABLE = ${taxi['isAvailable']}");
    debugPrint(
      "🚕 LOCATION = ${location?.lat},${location?.lng}",
    );
    debugPrint(
      "🚕 LOCATION SOURCE = ${location?.source.name}",
    );

    if (location == null) {
      continue;
    }

    final position = location.latLng;

    _firstDriverPosition ??= position;

    markers.add(
      Marker(
        markerId: MarkerId(doc.id),
        icon: _driverMarker ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose,
            ),
        position: position,
        infoWindow: InfoWindow(
          title: _businessName(data, taxi),
          snippet: 'Available Pet Taxi',
        ),
      ),
    );

    _initialCameraPosition ??=
        CameraPosition(target: position, zoom: 16);

    _moveCameraToDriverIfNeeded(position);
  }

  if (!mounted) {
    return;
  }

  setState(() {
    _markers = markers;
  });
}

  @override
  Widget build(BuildContext context) {
    if (!_pageReady) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              trackMapCreated(
                data: <String, dynamic>{
                  'page': 'PetTaxiMapPage',
                  'hasInitialDriverPosition': _firstDriverPosition != null,
                },
              );
              final firstDriverPosition = _firstDriverPosition;
              if (firstDriverPosition != null) {
                _moveCameraToDriverIfNeeded(firstDriverPosition);
              }
            },
            initialCameraPosition:
                _initialCameraPosition ?? _fallbackCameraPosition,
            markers: _markers,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        Positioned(
          right: 18,
          bottom: 170,
          child: CurrentLocationButton(
            onTap: () {
              _moveCameraToUser();
            },
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: PetTaxiBottomSheet(),
        ),
      ],
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    return <String, dynamic>{};
  }

  void _moveCameraToDriverIfNeeded(LatLng position) {
    if (_mapController != null && !_cameraMoved) {
      _cameraMoved = true;

      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) {
          return;
        }

        final GoogleMapController? controller = _mapController;
        if (controller == null) {
          return;
        }

        try {
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: position, zoom: 18),
            ),
          );
          _markMapReadyFromSuccessfulCameraMovement(
            trigger: 'firstDriver',
            data: <String, dynamic>{
              'latitude': position.latitude,
              'longitude': position.longitude,
              'zoom': 18,
            },
          );
        } catch (e, stackTrace) {
          await reportMapInitializationFailure(
            error: e,
            stackTrace: stackTrace,
            message:
                'Pet Taxi map initialization failed while focusing first driver',
            data: <String, dynamic>{
              'page': 'PetTaxiMapPage',
              'driverLatitude': position.latitude,
              'driverLongitude': position.longitude,
              'stage': 'focusFirstDriver',
            },
          );
        }
      });
    }
  }

  void _markMapReadyFromSuccessfulCameraMovement({
    required String trigger,
    Map<String, dynamic>? data,
  }) {
    if (!_firstSuccessfulCameraMovementTracked) {
      _firstSuccessfulCameraMovementTracked = true;
      trackFirstSuccessfulCameraMovement(
        data: <String, dynamic>{
          'page': 'PetTaxiMapPage',
          'trigger': trigger,
          ...?data,
        },
      );
    }

    completeGoogleMapHealthCheck(
      data: <String, dynamic>{
        'page': 'PetTaxiMapPage',
        'trigger': trigger,
        ...?data,
      },
    );
  }

  String _businessName(Map<String, dynamic> data, Map<String, dynamic> taxi) {
    final profile = _map(data['profile']);

    final values = [
      profile['displayName'],
      taxi['displayName'],
      data['businessName'],
      data['name'],
    ];

    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return 'Pet Taxi';
  }
}
