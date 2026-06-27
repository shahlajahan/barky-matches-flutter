import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../widgets/current_location_button.dart';
import '../widgets/pet_taxi_bottom_sheet.dart';

class PetTaxiMapPage extends StatefulWidget {
  const PetTaxiMapPage({super.key});

  @override
  State<PetTaxiMapPage> createState() => _PetTaxiMapPageState();
}

class _PetTaxiMapPageState extends State<PetTaxiMapPage> {
  static const CameraPosition _fallbackCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 11,
  );

  CameraPosition? _initialCameraPosition;
  GoogleMapController? _mapController;
  bool _cameraMoved = false;
  LatLng? _firstDriverPosition;
  Set<Marker> _markers = const {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driversSubscription;
  BitmapDescriptor? _driverMarker;

  Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
    return FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _loadDriverMarker();
    _driversSubscription = _driversStream().listen(_handleDriversSnapshot);
    _debugUserLocation();
  }

  Future<void> _debugUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();

      debugPrint(
        "👤 USER GPS = "
        "${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      debugPrint("❌ USER GPS ERROR = $e");
    }
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadDriverMarker() async {
  _driverMarker = await BitmapDescriptor.asset(
    const ImageConfiguration(
      size: Size(56, 56),
    ),
    "assets/taxi_marker.png",
  );

  if (mounted) {
    setState(() {});
  }
}

  void _handleDriversSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final markers = <Marker>{};

    for (final doc in snapshot.docs) {
      final data = {...doc.data(), 'id': doc.id};

      final sectorData = _map(data['sectorData']);

      final taxi = _map(
        sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
      );

      if (taxi['isAvailable'] != true) {
        continue;
      }

      final currentLocation = _map(taxi['currentLocation']);
      final contact = _map(data['contact']);
      final fallbackLocation = _map(contact['location']);
      final location = currentLocation.isNotEmpty
          ? currentLocation
          : fallbackLocation;

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();

      debugPrint("🚕 DRIVER = ${_businessName(data, taxi)}");
      debugPrint("🚕 AVAILABLE = ${taxi['isAvailable']}");
      debugPrint("🚕 LOCATION = $lat,$lng");

      if (lat == null || lng == null) {
        continue;
      }

      final position = LatLng(lat, lng);

      _firstDriverPosition ??= position;
      debugPrint("🚕 DRIVER POSITION = $lat,$lng");
      debugPrint("🚕 MARKER ADDED -> ${doc.id}");

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

      _initialCameraPosition ??= CameraPosition(target: position, zoom: 16);
      _moveCameraToDriverIfNeeded(position);
    }

    if (!mounted) return;

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) {
              debugPrint("🗺️ MAP TAP");
            },
            onCameraMove: (position) {
              debugPrint("🗺️ CAMERA MOVED -> ${position.zoom}");
            },
          ),
        ),
        const Positioned(
          right: 18,
          bottom: 170,
          child: CurrentLocationButton(),
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

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        debugPrint("🎯 CAMERA MOVED TO DRIVER");
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: position, zoom: 18),
          ),
        );
      });
    }
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
