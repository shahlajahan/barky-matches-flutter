import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminMapMonitorPage extends StatefulWidget {
  const AdminMapMonitorPage({super.key});

  @override
  State<AdminMapMonitorPage> createState() => _AdminMapMonitorPageState();
}

class _AdminMapMonitorPageState extends State<AdminMapMonitorPage> {

  GoogleMapController? mapController;

  final Set<Marker> _markers = {};

  bool showBusinesses = true;
  bool showAdoptions = true;
  bool showLostDogs = true;
  bool showReports = true;

  BitmapDescriptor? businessIcon;
  BitmapDescriptor? dogIcon;
  BitmapDescriptor? lostIcon;
  BitmapDescriptor? reportIcon;

  @override
  void initState() {
    super.initState();
    _loadIcons();
    _loadMarkers();
  }

  Future<void> _loadIcons() async {

    businessIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue);

    dogIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen);

    lostIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed);

    reportIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange);
  }

  Future<void> _loadMarkers() async {

    debugPrint("🗺 Loading markers...");

    final markers = <Marker>{};

    if (showBusinesses) {

      debugPrint("📡 Query businesses collection");

      final snapshot = await FirebaseFirestore.instance
          .collection("businesses")
          .get();

      debugPrint("📦 Businesses fetched: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {

        final data = doc.data();

        debugPrint("-----");
        debugPrint("BUSINESS ID => ${doc.id}");
        debugPrint("DATA => $data");

        Map<String, dynamic>? location;

        /// NEW STRUCTURE (recommended)
        if (data["location"] != null) {
          location = Map<String, dynamic>.from(data["location"]);
          debugPrint("📍 location found at root");
        }

        /// CURRENT STRUCTURE
        else if (data["contact"]?["location"] != null) {
          location = Map<String, dynamic>.from(
              data["contact"]["location"]);
          debugPrint("📍 location found at contact.location");
        }

        if (location == null) {
          debugPrint("❌ No location found");
          continue;
        }

        final lat = location["lat"];
        final lng = location["lng"];

        debugPrint("LAT => $lat");
        debugPrint("LNG => $lng");

        if (lat == null || lng == null) {
          debugPrint("❌ Lat/Lng null");
          continue;
        }

        final latDouble = (lat as num).toDouble();
        final lngDouble = (lng as num).toDouble();

        debugPrint("✅ Marker added");

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            icon: businessIcon ?? BitmapDescriptor.defaultMarker,
            position: LatLng(latDouble, lngDouble),
            infoWindow: InfoWindow(
              title: data["profile"]?["displayName"] ?? "Business",
              snippet: data["status"] ?? "",
            ),
          ),
        );
      }
    }

    debugPrint("🎯 Total markers: ${markers.length}");

    if (!mounted) return;

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  void _toggle(String type) {

    setState(() {

      if (type == "business") {
        showBusinesses = !showBusinesses;
      }

      if (type == "adoption") {
        showAdoptions = !showAdoptions;
      }

      if (type == "lost") {
        showLostDogs = !showLostDogs;
      }

      if (type == "reports") {
        showReports = !showReports;
      }

    });

    _loadMarkers();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Map Monitor"),
        backgroundColor: Colors.pink,
      ),

      body: Stack(
        children: [

          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.015137, 28.979530),
              zoom: 10,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _filterPanel(),
          )
        ],
      ),
    );
  }

  Widget _filterPanel() {

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8),

        child: Wrap(
          spacing: 8,

          children: [

            FilterChip(
              label: const Text("Businesses"),
              selected: showBusinesses,
              onSelected: (_) => _toggle("business"),
            ),

            FilterChip(
              label: const Text("Adoption"),
              selected: showAdoptions,
              onSelected: (_) => _toggle("adoption"),
            ),

            FilterChip(
              label: const Text("Lost Dogs"),
              selected: showLostDogs,
              onSelected: (_) => _toggle("lost"),
            ),

            FilterChip(
              label: const Text("Reports"),
              selected: showReports,
              onSelected: (_) => _toggle("reports"),
            ),
          ],
        ),
      ),
    );
  }
}