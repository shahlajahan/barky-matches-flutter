import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'dog.dart';
import 'play_date_request.dart';
import 'notification_service.dart';
import 'dart:convert';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';



Future<Position?> _getCurrentPosition(SendPort sendPort) async {
  try {
    if (RootIsolateToken.instance != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(RootIsolateToken.instance!);
    } else {
      if (kDebugMode) {
        print('PlayDateSchedulingPage - RootIsolateToken.instance is null');
      }
      sendPort.send(null);
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
    sendPort.send(position);
    return position;
  } catch (e) {
    if (kDebugMode) {
      print('PlayDateSchedulingPage - Error getting current position: $e');
    }
    sendPort.send(null);
    return null;
  }
}

class PlayDateSchedulingPage extends StatefulWidget {
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const PlayDateSchedulingPage({
    super.key,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _PlayDateSchedulingPageState createState() => _PlayDateSchedulingPageState();
}

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerPage({super.key, required this.initialLocation});

  @override
  _MapPickerPageState createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(0, 0);
  bool _isLoading = true;
  String? _errorMessage;
  String? _mapStyle;
  late final BitmapDescriptor _customMarker;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _loadCustomMarker();
    _checkApiKeyAndLoadMap();
  }

  Future<void> _loadCustomMarker() async {
    try {
      _customMarker = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/marker_icon.png',
      );
    } catch (e) {
      if (kDebugMode) {
        print('MapPickerPage - Error loading custom marker: $e');
      }
      _customMarker = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _checkApiKeyAndLoadMap() async {
    try {
      final apiKey = await _getApiKeyFromManifest();
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _errorMessage = 'API Key not found. Please check AndroidManifest.xml.';
          _isLoading = false;
        });
        return;
      }
      _mapStyle = await compute(_loadMapStyleIsolate, DefaultAssetBundle.of(context));
      if (kDebugMode) {
        print('MapPickerPage - Map style loaded successfully');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('MapPickerPage - Error loading map style: $e');
      }
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }

  static Future<String?> _loadMapStyleIsolate(AssetBundle bundle) async {
    try {
      return await bundle.loadString('assets/map_style.json');
    } catch (e) {
      if (kDebugMode) {
        print('MapPickerPage - Error loading map style in Isolate: $e');
      }
      return null;
    }
  }

  Future<String?> _getApiKeyFromManifest() async {
    return 'AIzaSyBNTAUakHQxsfbCkCEdLdBUSR9o8J7tqEU';
  }

  void _onMapCreated(GoogleMapController controller) {
    if (_mapController == null) {
      _mapController = controller;
      if (_mapStyle != null) {
        _mapController!.setMapStyle(_mapStyle);
      }
    }
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectLocation, style: GoogleFonts.poppins()),
        backgroundColor: Colors.pink,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: widget.initialLocation,
                        zoom: 12.0,
                      ),
                      onTap: _onTap,
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected-location'),
                          position: _selectedLocation,
                          icon: _customMarker,
                        ),
                      },
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      buildingsEnabled: false,
                      trafficEnabled: false,
                    ),
                    Positioned(
                      bottom: 16.0,
                      left: 16.0,
                      right: 16.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFC107),
                        ),
                        onPressed: () {
                          if (_errorMessage == null) {
                            Navigator.pop(context, _selectedLocation);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_errorMessage!)),
                            );
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.confirmLocation, style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _PlayDateSchedulingPageState extends State<PlayDateSchedulingPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedLocation;
  String? _selectedRequesterDogId;
  String? _selectedRequestedDogId;
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadRequests();
    _loadInitialLocation();
  }

  Future<void> _initializeAndLoadRequests() async {
    try {
      await _notificationService.init();
      if (kDebugMode) {
        print('PlayDateSchedulingPage - NotificationService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('PlayDateSchedulingPage - Error initializing NotificationService: $e');
      }
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  Future<void> _loadInitialLocation() async {
    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_getCurrentPosition, receivePort.sendPort);
    final Position? currentPosition = await receivePort.first as Position?;

    if (currentPosition != null && mounted) {
      setState(() {
        _selectedLocation = 'Lat: ${currentPosition.latitude}, Long: ${currentPosition.longitude}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            primaryColor: Colors.pink,
            colorScheme: ColorScheme.fromSwatch().copyWith(
              secondary: const Color(0xFFFFC107),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            primaryColor: Colors.pink,
            colorScheme: ColorScheme.fromSwatch().copyWith(
              secondary: const Color(0xFFFFC107),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectLocation() async {
    String? location;
    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_getCurrentPosition, receivePort.sendPort);
    final Position? currentPosition = await receivePort.first as Position?;

    // اطمینان از به‌روزرسانی زبان
    final localizations = AppLocalizations.of(context)!;
    if (kDebugMode) {
      print('PlayDateSchedulingPage - Current locale: ${Localizations.localeOf(context)}');
    }

    final selectedOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.selectLocation),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: localizations.enterLocation,
                  labelText: localizations.locationLabel,
                ),
                controller: TextEditingController(
                    text: _selectedLocation ??
                        (currentPosition != null
                            ? 'Lat: ${currentPosition.latitude}, Long: ${currentPosition.longitude}'
                            : null)),
                onChanged: (value) => location = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFFC107),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  final LatLng? pickedLocation = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapPickerPage(
                        initialLocation: currentPosition != null
                            ? LatLng(currentPosition.latitude, currentPosition.longitude)
                            : const LatLng(41.0103, 28.6724),
                      ),
                    ),
                  );
                  if (pickedLocation != null && mounted) {
                    location = 'Lat: ${pickedLocation.latitude}, Long: ${pickedLocation.longitude}';
                    Navigator.pop(context, location);
                  }
                },
                child: Text(
                  localizations.pickOnMap,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.quickLocations,
                style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFFC107),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () {
                      setState(() {
                        location = 'Lat: 41.0103, Long: 28.6724 (${localizations.parkA})';
                      });
                      Navigator.pop(context, location);
                    },
                    child: Text(
                      localizations.parkA,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFFC107),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () {
                      setState(() {
                        location = 'Lat: 41.0156, Long: 28.6789 (${localizations.parkB})';
                      });
                      Navigator.pop(context, location);
                    },
                    child: Text(
                      localizations.parkB,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(localizations.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(localizations.confirm),
            onPressed: () => Navigator.pop(context, location),
          ),
        ],
      ),
    );

    if (selectedOption != null && mounted) {
      setState(() {
        _selectedLocation = selectedOption;
      });
    }
  }

  Future<void> _createPlayDateRequest() async {
    if (kDebugMode) {
      print('PlayDateSchedulingPage - Starting _createPlayDateRequest');
    }
    if (_selectedDate == null ||
        _selectedTime == null ||
        _selectedLocation == null ||
        _selectedRequesterDogId == null ||
        _selectedRequestedDogId == null) {
      if (kDebugMode) {
        print(
            'PlayDateSchedulingPage - Validation failed: _selectedDate=$_selectedDate, _selectedTime=$_selectedTime, _selectedLocation=$_selectedLocation, _selectedRequesterDogId=$_selectedRequesterDogId, _selectedRequestedDogId=$_selectedRequestedDogId');
      }
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectBothDogs)),
      );
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (kDebugMode) {
      print('PlayDateSchedulingPage - CurrentUserId: $currentUserId');
    }
    if (currentUserId.isEmpty) {
      if (kDebugMode) {
        print('PlayDateSchedulingPage - No authenticated user found');
      }
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginToCreateRequest)),
      );
      return;
    }

    final requesterDog = widget.dogsList.firstWhere(
      (dog) => dog.ownerId == currentUserId && dog.name == _selectedRequesterDogId,
      orElse: () => throw Exception('Selected requester dog not found: $_selectedRequesterDogId'),
    );

    final requestedDog = widget.dogsList.firstWhere(
      (dog) => dog.ownerId == _selectedRequestedDogId,
      orElse: () => throw Exception('Selected requested dog not found: $_selectedRequestedDogId'),
    );

    String requesterName = 'Unknown User';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        requesterName = userDoc.data()?['username']?.toString() ?? 'Unknown User';
      }
    } catch (e) {
      if (kDebugMode) {
        print('PlayDateSchedulingPage - Error fetching requesterName: $e');
      }
    }

    final selectedDogOwnerId = requestedDog.ownerId;
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final newRequest = PlayDateRequest(
      requestId: '',
      requesterUserId: currentUserId,
      requestedUserId: selectedDogOwnerId,
      requesterDog: requesterDog,
      requestedDog: requestedDog,
      status: 'pending',
      requestDate: DateTime.now(),
      scheduledDateTime: scheduledDateTime,
      requesterName: requesterName,
      message: 'Playdate request for ${requestedDog.name}',
      location: _selectedLocation,
    );

    if (kDebugMode) {
      print('PlayDateSchedulingPage - Creating request: $newRequest');
    }
    try {
      final docRef = await FirebaseFirestore.instance.collection('playDateRequests').add(newRequest.toMap());
      if (kDebugMode) {
        print('✅ PlayDateSchedulingPage - Request created with ID: ${docRef.id}');
      }

      final bodyText = AppLocalizations.of(context)!.playdateRequestBody.toString();
      await _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: AppLocalizations.of(context)!.newPlayDateRequestTitle,
        body: bodyText.replaceAll('{requesterDog}', newRequest.requesterDog.name).replaceAll('{requestedDog}', newRequest.requestedDog.name),
        likerUserId: currentUserId,
        payload: jsonEncode({
          'type': 'playDateRequest',
          'requestId': docRef.id,
          'requesterUserId': currentUserId,
        }),
      );

      final notificationBodyText = AppLocalizations.of(context)!.playdateRequestBody.toString();
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': requestedDog.ownerId,
        'timestamp': FieldValue.serverTimestamp(),
        'title': AppLocalizations.of(context)!.newPlayDateRequestTitle,
        'body': notificationBodyText.replaceAll('{requesterDog}', newRequest.requesterDog.name).replaceAll('{requestedDog}', newRequest.requestedDog.name),
        'payload': jsonEncode({
          'type': 'playdateRequest',
          'requestId': docRef.id,
          'requesterUserId': currentUserId,
        }),
        'isRead': false,
      });

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.requestCreatedSuccess)),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlayDateSchedulingPage - Error creating request: $e');
      }
      final errorText = AppLocalizations.of(context)!.errorCreatingRequest.toString();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(errorText.replaceAll('{error}', e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.schedulePlaydate,
            style: GoogleFonts.dancingScript(
              color: const Color(0xFFFFC107),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.pink,
        ),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.pleaseLoginToSchedulePlaydate,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFC107),
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.schedulePlaydate,
          style: GoogleFonts.dancingScript(
            color: const Color(0xFFFFC107),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectDateAndTime,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFC107),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () => _selectDate(context),
                        child: Text(
                          _selectedDate == null
                              ? AppLocalizations.of(context)!.pickDate
                              : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFC107),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () => _selectTime(context),
                        child: Text(
                          _selectedTime == null
                              ? AppLocalizations.of(context)!.pickTime
                              : _selectedTime!.format(context),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.selectLocation,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFFC107),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () async {
                      await _selectLocation();
                    },
                    child: Text(
                      _selectedLocation ?? AppLocalizations.of(context)!.selectLocation,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.selectYourDog,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(
                      AppLocalizations.of(context)!.selectYourDogHint,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFC107),
                        fontSize: 14,
                      ),
                    ),
                    value: _selectedRequesterDogId,
                    items: widget.dogsList
                        .where((dog) => dog.ownerId == currentUserId)
                        .map<DropdownMenuItem<String>>((dog) => DropdownMenuItem<String>(
                              value: dog.name,
                              child: Text(
                                dog.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRequesterDogId = value;
                      });
                    },
                    dropdownColor: Colors.pinkAccent,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFC107),
                      fontSize: 14,
                    ),
                    iconEnabledColor: const Color(0xFFFFC107),
                    underline: Container(
                      height: 1,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.selectFriendsDog,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(
                      AppLocalizations.of(context)!.selectFriendsDogHint,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFC107),
                        fontSize: 14,
                      ),
                    ),
                    value: _selectedRequestedDogId,
                    items: widget.dogsList
                        .where((dog) => dog.ownerId != currentUserId)
                        .map<DropdownMenuItem<String>>((dog) => DropdownMenuItem<String>(
                              value: dog.ownerId,
                              child: Text(
                                dog.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRequestedDogId = value;
                      });
                    },
                    dropdownColor: Colors.pinkAccent,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFC107),
                      fontSize: 14,
                    ),
                    iconEnabledColor: const Color(0xFFFFC107),
                    underline: Container(
                      height: 1,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFFC107),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: _createPlayDateRequest,
                      child: Text(
                        AppLocalizations.of(context)!.sendRequestButton,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}