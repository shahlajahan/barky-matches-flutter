import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


class DogParkPage extends StatefulWidget {
  const DogParkPage({super.key});

  @override
  State<DogParkPage> createState() => _DogParkPageState();
}

class _DogParkPageState extends State<DogParkPage> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _errorMessage;
  String? _mapStyle;
  BitmapDescriptor? _customMarker;

  final List<Map<String, dynamic>> _dogParks = const [
    {
      'name': 'Yıldız Parkı',
      'latitude': 41.0489,
      'longitude': 29.0155,
      'description': 'A large park in Beşiktaş with plenty of space for dogs.',
    },
    {
      'name': 'Maçka Parkı',
      'latitude': 41.0425,
      'longitude': 28.9941,
      'description': 'A popular park in Şişli, great for dog walking.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    if (kDebugMode) {
      print('DogParkPage - Initializing in initState');
    }
    Future.microtask(() async {
      await _loadMapStyle();
      await _loadCustomMarker();
      await _requestPermissions();
    });
  }

  Future<void> _loadCustomMarker() async {
    try {
      final byteData = await rootBundle.load('assets/marker_icon.png');
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: 16,
        targetHeight: 16,
      );
      final frame = await codec.getNextFrame();
      final bitmap = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      _customMarker = BitmapDescriptor.fromBytes(bitmap!.buffer.asUint8List());
      if (kDebugMode) {
        print('DogParkPage - Custom marker loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DogParkPage - Error loading custom marker: $e');
      }
      _customMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
      if (kDebugMode) {
        print('DogParkPage - Map style loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DogParkPage - Error loading map style: $e');
      }
      _mapStyle = null;
    }
  }

  Future<void> _requestPermissions() async {
    final l10n = AppLocalizations.of(context)!;
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        if (kDebugMode) {
          print('DogParkPage - Location permission denied');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.dogParkPermissionDenied;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.dogParkPermissionRequired),
              action: SnackBarAction(
                label: l10n.dogParkSettingsAction,
                onPressed: () async {
                  await openAppSettings();
                  await _requestPermissions();
                },
              ),
            ),
          );
        }
        return;
      }
    }

    var backgroundStatus = await Permission.locationAlways.status;
    if (!backgroundStatus.isGranted) {
      backgroundStatus = await Permission.locationAlways.request();
      if (!backgroundStatus.isGranted) {
        if (kDebugMode) {
          print('DogParkPage - Background location permission denied');
        }
        setState(() {
          _errorMessage = l10n.dogParkBackgroundPermissionDenied;
          _isLoading = false;
          _currentPosition = Position(
            latitude: 41.0457,
            longitude: 29.0048,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          _animationController.forward();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.dogParkBackgroundRecommended),
              action: SnackBarAction(
                label: l10n.dogParkSettingsAction,
                onPressed: () async {
                  await openAppSettings();
                  await _requestPermissions();
                },
              ),
            ),
          );
        }
        await _addParkMarkers();
        return;
      }
    }

    await _getCurrentLocationWithRetry();
  }

  Future<void> _getCurrentLocationWithRetry({int retries = 3, Duration delay = const Duration(seconds: 1)}) async {
    final l10n = AppLocalizations.of(context)!;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (kDebugMode) {
            print('DogParkPage - Location services are disabled.');
          }
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.dogParkLocationServicesDisabled;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.dogParkEnableLocationServices),
                action: SnackBarAction(
                  label: l10n.dogParkSettingsAction,
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                    await _requestPermissions();
                  },
                ),
              ),
            );
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (kDebugMode) {
              print('DogParkPage - Location permission denied');
            }
            setState(() {
              _isLoading = false;
              _errorMessage = l10n.dogParkPermissionDenied;
            });
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (kDebugMode) {
            print('DogParkPage - Location permission permanently denied');
          }
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.dogParkPermissionsDenied;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.dogParkPermissionsDenied),
                action: SnackBarAction(
                  label: l10n.dogParkSettingsAction,
                  onPressed: () async {
                    await openAppSettings();
                    await _requestPermissions();
                  },
                ),
              ),
            );
          }
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _errorMessage = null;
          _animationController.forward();
          if (kDebugMode) {
            print('DogParkPage - Current position: ${position.latitude}, ${position.longitude}');
          }
        });
        await _addParkMarkers();
        return;
      } catch (e) {
        if (kDebugMode) {
          print('DogParkPage - Attempt $attempt failed to get location: $e');
        }
        if (attempt == retries) {
          try {
            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              setState(() {
                _currentPosition = lastPosition;
                _isLoading = false;
                _errorMessage = null;
                _animationController.forward();
                if (kDebugMode) {
                  print('DogParkPage - Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
                }
              });
              await _addParkMarkers();
              return;
            } else {
              setState(() {
                _isLoading = false;
                _errorMessage = l10n.dogParkLocationError(e.toString());
                _currentPosition = Position(
                  latitude: 41.0457,
                  longitude: 29.0048,
                  timestamp: DateTime.now(),
                  accuracy: 0.0,
                  altitude: 0.0,
                  heading: 0.0,
                  speed: 0.0,
                  speedAccuracy: 0.0,
                  altitudeAccuracy: 0.0,
                  headingAccuracy: 0.0,
                );
                _animationController.forward();
                if (kDebugMode) {
                  print('DogParkPage - Fallback to default position: 41.0457, 29.0048');
                }
              });
              await _addParkMarkers();
              return;
            }
          } catch (fallbackError) {
            setState(() {
              _isLoading = false;
              _errorMessage = l10n.dogParkLocationError(fallbackError.toString());
              _currentPosition = Position(
                latitude: 41.0457,
                longitude: 29.0048,
                timestamp: DateTime.now(),
                accuracy: 0.0,
                altitude: 0.0,
                heading: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
                altitudeAccuracy: 0.0,
                headingAccuracy: 0.0,
              );
              _animationController.forward();
              if (kDebugMode) {
                print('DogParkPage - Fallback to default position after error: $fallbackError');
              }
            });
            await _addParkMarkers();
            return;
          }
        }
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _addParkMarkers() async {
    final markers = <Marker>[];
    const maxParks = 5; // محدود کردن تعداد مارکرها برای عملکرد بهتر
    for (var park in _dogParks.take(maxParks)) {
      if (_currentPosition != null) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          park['latitude'],
          park['longitude'],
        ) / 1000;
        if (distance <= 50) {
          markers.add(
            Marker(
              markerId: MarkerId(park['name']),
              position: LatLng(park['latitude'], park['longitude']),
              infoWindow: InfoWindow(
                title: park['name'],
                snippet: park['description'],
              ),
              icon: _customMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        }
      }
    }
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
      if (kDebugMode) {
        print('DogParkPage - Added ${_markers.length} park markers');
      }
      if (_mapController != null && _markers.isNotEmpty) {
        _moveCameraToMarkers();
      }
    });
  }

  Future<void> _moveCameraToMarkers() async {
    if (_mapController != null && _markers.isNotEmpty) {
      LatLngBounds bounds = LatLngBounds(
        southwest: const LatLng(41.0425, 28.9941),
        northeast: const LatLng(41.0489, 29.0155),
      );
      await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
      if (kDebugMode) {
        print('DogParkPage - Camera moved to markers');
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _animationController.dispose();
    super.dispose();
    if (kDebugMode) {
      print('DogParkPage - Disposed map and animation controllers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          l10n.dogParkTitle,
          style: GoogleFonts.dancingScript(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  l10n.dogParkDateLabel(DateFormat('EEEE, MMMM dd, yyyy, hh:mm a Z').format(DateTime.now())),
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
              Expanded(
                child: RepaintBoundary(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _currentPosition != null
                                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                    : const LatLng(41.0457, 29.0048),
                                zoom: 14,
                              ),
                              markers: _markers,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: true,
                              zoomGesturesEnabled: true,
                              scrollGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              buildingsEnabled: false,
                              trafficEnabled: false,
                              mapType: MapType.normal,
                              minMaxZoomPreference: const MinMaxZoomPreference(10, 15),
                              compassEnabled: false, // غیرفعال برای کاهش مصرف منابع
                              indoorViewEnabled: false, // غیرفعال برای کاهش مصرف منابع
                              onCameraMove: (_) {
                                if (kDebugMode) {
                                  print('DogParkPage - Camera moved');
                                }
                              },
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;
                                if (_mapStyle != null) {
                                  _mapController!.setMapStyle(_mapStyle);
                                  if (kDebugMode) {
                                    print('DogParkPage - Applied map style');
                                  }
                                }
                                _moveCameraToMarkers();
                              },
                            ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _addParkMarkers,
                    child: Text(l10n.dogParkLoadMarkers),
                  ),
                  ElevatedButton(
                    onPressed: _moveCameraToMarkers,
                    child: Text(l10n.dogParkMoveToMarkers),
                  ),
                ],
              ),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: _dogParks.length,
                    cacheExtent: 1000.0,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final park = _dogParks[index];
                      final distance = _currentPosition != null
                          ? Geolocator.distanceBetween(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              park['latitude'],
                              park['longitude'],
                            ) / 1000
                          : 0.0;
                      return Card(
                        color: Colors.white.withValues(alpha: 0.9), // جایگزین withOpacity
                        child: ListTile(
                          title: Text(
                            park['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${park['description']}\n${l10n.dogParkDistanceLabel(distance.toStringAsFixed(2))}',
                            style: GoogleFonts.poppins(),
                          ),
                          onTap: () {
                            if (_mapController != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(park['latitude'], park['longitude']),
                                  15,
                                ),
                              );
                              if (kDebugMode) {
                                print('DogParkPage - Tapped park: ${park['name']}');
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}