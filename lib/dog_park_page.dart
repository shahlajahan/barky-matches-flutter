

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/shell/barky_scaffold.dart';
import 'package:barky_matches_fixed/play_date_scheduling_page.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/playmate_page.dart';
import 'package:barky_matches_fixed/playdate_flow_router.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:hive_flutter/hive_flutter.dart';




class DogParkPage extends StatefulWidget {
  final String? initialParkName;
  final Dog? requestedDog;

  const DogParkPage({
    super.key,
    this.initialParkName,
    this.requestedDog,
  });

  @override
  State<DogParkPage> createState() => _DogParkPageState();
}


class _DogParkPageState extends State<DogParkPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _mapStyle;
  BitmapDescriptor? _customMarker;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  bool _playdateFlowPushed = false;

  static const Color _bgSoftPink = Color(0xFFFFF6F8);
  static const LatLng _fallbackLatLng = LatLng(41.0457, 29.0048);

  final List<Map<String, dynamic>> _dogParks = const [
    {
      'name': 'Yaşam Vadisi',
      'lat': 41.0159,
      'lng': 28.6466,
      'description': 'Large green valley, very popular with dog owners',
      'recommended': true,
      'premiumOnly': false,
    },
    {
      'name': 'Maçka Demokrasi Parkı',
      'lat': 41.0425,
      'lng': 28.9941,
      'description': 'Central park, ideal for walking dogs',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Yıldız Parkı',
      'lat': 41.0489,
      'lng': 29.0155,
      'description': 'Historic park with wide paths for dogs',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Fenerbahçe Parkı',
      'lat': 40.9700,
      'lng': 29.0387,
      'description': 'Seaside park, dog-friendly walking routes',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Caddebostan Sahil Parkı',
      'lat': 40.9633,
      'lng': 29.0636,
      'description': 'Long coastal park popular among dog owners',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Emirgan Korusu',
      'lat': 41.1050,
      'lng': 29.0560,
      'description': 'Large forest park, great for dogs on leash',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Atatürk Kent Ormanı',
      'lat': 41.1596,
      'lng': 29.0265,
      'description': 'Modern forest park with long walking trails',
      'recommended': true,
      'premiumOnly': true,
    },
    {
      'name': 'Validebağ Korusu',
      'lat': 41.0186,
      'lng': 29.0477,
      'description': 'Natural protected green area, calm environment',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Florya Atatürk Ormanı',
      'lat': 40.9793,
      'lng': 28.7855,
      'description': 'Urban forest, suitable for dog walks',
      'recommended': false,
      'premiumOnly': false,
    },
    {
      'name': 'Büyükçekmece Sahil Parkı',
      'lat': 41.0207,
      'lng': 28.5850,
      'description': 'Wide coastal park, ideal for large dogs',
      'recommended': false,
      'premiumOnly': false,
    },
  ];

  @override
  bool get wantKeepAlive => true;


  @override
  void initState() {
    super.initState();
    debugPrint('🟢 DogPark initState ${hashCode}');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    Future.microtask(() async {
      await _loadMapStyle();
      await _loadCustomMarker();
      await _resolveLocation();
    });
  }

  // --------------------------------------------------
  // LOCATION
  // --------------------------------------------------
  Future<void> _resolveLocation() async {
    debugPrint('📍 resolveLocation START mounted=$mounted hash=$hashCode');

  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!; // ✅ بعد از mounted
      _useFallback(l10n.dogParkLocationServicesDisabled);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _useFallback(l10n.dogParkPermissionDenied);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 8),
    );

    if (!mounted) return;

    setState(() {
      _currentPosition = pos;
      _isLoading = false;
      _errorMessage = null;
    });

    _animationController.forward();
    await _addParkMarkers();

debugPrint('📍 after permission mounted=$mounted');
debugPrint('📍 after getCurrentPosition mounted=$mounted hash=$hashCode');


  } catch (e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _useFallback(l10n.dogParkLocationError(e.toString()));
  }
}


  void _useFallback(String message) {
  if (!mounted) return; // ✅ حیاتی

  setState(() {
    _currentPosition = Position(
      latitude: _fallbackLatLng.latitude,
      longitude: _fallbackLatLng.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _errorMessage = message;
    _isLoading = false;
  });

  if (!mounted) return;
  _animationController.forward();
  _addParkMarkers();
}

  // --------------------------------------------------
  // MAP SETUP
  // --------------------------------------------------
  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (_) {
      _mapStyle = null;
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final data = await rootBundle.load('assets/marker_icon.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      _customMarker = BitmapDescriptor.fromBytes(
        bytes!.buffer.asUint8List(),
      );
    } catch (_) {
      _customMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Future<void> _addParkMarkers() async {
  if (!mounted) return;

  final markers = <Marker>{};

  for (final park in _dogParks) {
    markers.add(
      Marker(
        markerId: MarkerId(park['name']),
        position: LatLng(park['lat'], park['lng']),
        icon: _customMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _openParkBottomSheet(park),
      ),
    );
  }

  if (!mounted) return;

  setState(() {
    _markers
      ..clear()
      ..addAll(markers);
  });

  _moveCameraToFitAllMarkers();
}


  // ⭐ مهم‌ترین اصلاح UX
  void _moveCameraToFitAllMarkers() {
    if (_mapController == null || _markers.isEmpty) return;
    final lats = _markers.map((m) => m.position.latitude).toList();
    final lngs = _markers.map((m) => m.position.longitude).toList();
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
      northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _focusParkOnMap(Map<String, dynamic> park) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(park['lat'], park['lng']),
        15,
      ),
    );
  }

  // --------------------------------------------------
  // BOTTOM SHEET
  // --------------------------------------------------
  void _openParkBottomSheet(Map<String, dynamic> park) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isFavorite = appState.isParkFavorite(park['name'] as String);
    final l10n = AppLocalizations.of(context)!;
    final isPremiumUser = appState.isPremium;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<AppState>(
          builder: (_, appState, __) {
            final bool isFavorite =
                appState.isParkFavorite(park['name'] as String);
            final bool isPremiumUser = appState.isPremium;
            final l10n = AppLocalizations.of(sheetContext)!;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ───────── Handle ─────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ───────── Title + Badges ─────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          park['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (park['recommended'] == true) _badge('⭐ Recommended'),
                      if (park['premiumOnly'] == true) _badge('🔒 Premium'),
                      if (isFavorite) _badge('❤️ Saved'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ───────── Description ─────────
                  Text(
                    park['description'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),

                  // ───────── Recommended Section ─────────
                  if (park['recommended'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 18,
                            color: Color(0xFFFFC107),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommended for Playdates',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ───────── Premium Logic ─────────
                  if (park['premiumOnly'] == true && !isPremiumUser)
                    _premiumLockedView(l10n)
                  else ...[
                    // ───── Save / Saved ─────
                    OutlinedButton.icon(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: const Color(0xFFFFC107),
                      ),
                      label: Text(
                        isFavorite ? 'Saved to Favorites' : 'Save this Park',
                        style: GoogleFonts.poppins(),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFFFC107),
                        ),
                      ),
                      onPressed: () {
                        appState.toggleFavoritePark(park);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ───── Get Directions ─────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation),
                        label: const Text('Get Directions'),
                        onPressed: () => _navigateToGoogleMaps(park),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ───── Schedule Playdate here (اصلاح‌شده) ─────
                    SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
  Navigator.pop(sheetContext);

  final appState = context.read<AppState>();
  final uid = appState.currentUserId;

  if (uid == null || uid.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not ready yet. Please try again.')),
    );
    return;
  }

  final myDogs = appState.allDogs.where((d) => d.ownerId == uid).toList();
  if (myDogs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You need to add a dog first')),
    );
    return;
  }

  appState.startPlaydateAtPark(park);

  appState.setCurrentTab(NavTab.playdateScheduling);
},
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFFC107),
      foregroundColor: Colors.black,
    ),
    child: const Text('Schedule Playdate here'),
  ),
),

                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // بقیه متدها بدون تغییر
  // --------------------------------------------------

  void _openSavedParksSheet(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final savedNames = appState.favoriteParkNames; // ✅ Set<String>


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───────── Handle ─────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ───────── Title ─────────
              Text(
                'Saved Parks',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // ───────── Empty State ─────────
              if (savedNames.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No saved parks yet',
                    style: GoogleFonts.poppins(),
                  ),
                )
              else
                ...savedNames.map((parkName) {
                  final park = _dogParks.firstWhere(
                    (p) => p['name'] == parkName,
                  );
                  final bool recommended = park['recommended'] == true;
                  final bool premiumOnly = park['premiumOnly'] == true;
                  final bool locked =
                      premiumOnly && appState.isPremium == false;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.park),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              park['name'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (recommended) _badge('⭐'),
                          if (locked) _badge('🔒'),
                        ],
                      ),
                      subtitle: Text(
                        park['description'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
  Navigator.pop(sheetContext);

  Future.microtask(() {
    _focusParkOnMap(park);
    _openParkBottomSheet(park);
  });
},

                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _premiumLockedView(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock, size: 32),
          const SizedBox(height: 8),
          Text(
            'This park is available for Premium members only.',
            style: GoogleFonts.poppins(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // TODO: Open Paywall
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToGoogleMaps(Map<String, dynamic> park) async {
    final lat = park['lat'];
    final lng = park['lng'];
    final googleMapsUrl = Uri.parse(
      'comgooglemaps://?daddr=$lat,$lng&directionsmode=walking',
    );
    final appleMapsUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng&dirflg=w',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      await launchUrl(
        appleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget _badge(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
 
 @override
@override
Widget build(BuildContext context) {
  super.build(context);
  return _buildBody(context);
}


/*
  if (pendingPark != null && !_playdateFlowPushed) {
    _playdateFlowPushed = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaydateFlowRouter(), // ❌ const نداشته باشه
        ),
      );

      if (mounted) {
        setState(() {
          _playdateFlowPushed = false;
        });
      } else {
        _playdateFlowPushed = false;
      }
    });
  }
*/

/*
  return Scaffold(
    backgroundColor: _bgSoftPink,
    appBar: AppBar(
      backgroundColor: _bgSoftPink,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Dog Park', // یا اگر ترجمه داری: l10n.dogParkTitle
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFFC107),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFFFC107)),
    ),
    body: SafeArea(
      top: false, // طبق استاندارد Tab/Pages تو (ولی اینجا TYPE D هم اوکیه)
      child: _buildBody(context),
    ),
  );
}
*/
  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: _bgSoftPink,
      child: Column(
        children: [
          // ───────── Date Label ─────────
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              l10n.dogParkDateLabel(
                DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
              ),
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFC107),
              ),
            ),
          ),

          // ───────── Saved Parks Entry (Temporary UX Entry Point) ─────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openSavedParksSheet(context),
                icon: const Icon(Icons.bookmark, size: 18),
                label: Text(
                  'Saved Parks',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC107),
                  side: const BorderSide(color: Color(0xFFFFC107)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ───────── Map ─────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFC107),
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _fallbackLatLng,
                        zoom: 11,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: false,
                      buildingsEnabled: false,
                      trafficEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_mapStyle != null) {
                          controller.setMapStyle(_mapStyle);
                        }
                        _moveCameraToFitAllMarkers();
                      },
                    ),
                  ),
          ),

          // ───────── Error Message ─────────
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🟢 DogPark initState ${hashCode}');
    //_mapController?.dispose();
    _animationController.dispose();
    super.dispose();
  }
}