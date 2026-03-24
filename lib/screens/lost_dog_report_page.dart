import 'dart:async';
import 'dart:convert';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../models/lost_dog.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';

import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class LostDogReportPage extends StatefulWidget {
  const LostDogReportPage({super.key});

  @override
  State<LostDogReportPage> createState() => _LostDogReportPageState();
}

class _LostDogReportPageState extends State<LostDogReportPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  String? _selectedBreed;

  final _colorController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedCollarType;
  final _clothingColorController = TextEditingController();
  final _lostLocationController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _descriptionController = TextEditingController();

  Position? _currentPosition;
  bool _isSubmitting = false;
  bool _isPickingImage = false;

  String? _selectedContactType;

  String? _selectedGender;
String? _selectedHealthStatus;
File? _selectedImage;
bool _isUploadingImage = false;

final List<String> _contactTypes = [
  "Phone",
  "Email",
  "Instagram",
];

  final List<String> _collarTypes = ['Leather', 'Nylon', 'Chain', 'Other'];
  final List<String> _genders = ['Male', 'Female'];
final List<String> _healthStatuses = [
  'Healthy',
  'Injured',
  'Needs Medication',
  'Special Needs'
];

  Position _defaultPosition() {
    return Position(
      latitude: 41.0103,
      longitude: 28.6724,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrapLocation();
  }

  Future<void> _pickImage() async {
  if (_isPickingImage) return;

  try {
    _isPickingImage = true;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  } catch (e) {
    debugPrint("ImagePicker error: $e");
  } finally {
    _isPickingImage = false;
  }
}

Future<String?> _uploadImage(String docId) async {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return null;

  if (_selectedImage == null) return null;

  try {
    setState(() => _isUploadingImage = true);

    final ref = FirebaseStorage.instance
        .ref()
        .child('lost_dogs/${user.uid}/$docId.jpg');

    await ref.putFile(_selectedImage!);
    final url = await ref.getDownloadURL();

    return url;
  } catch (e) {
    debugPrint("Image upload error: $e");
    return null;
  } finally {
    setState(() => _isUploadingImage = false);
  }
}

  Future<void> _bootstrapLocation() async {
    final pos = await _safeGetPosition(timeout: const Duration(seconds: 8));
    if (!mounted) return;

    setState(() {
      _currentPosition = pos ?? _defaultPosition();
    });

    if (pos == null && kDebugMode) {
      debugPrint("LostDogReportPage - Using default/lastKnown position (safe)");
    }
  }

  /// ✅ SAFE location getter:
  /// - permission check
  /// - lastKnown fallback
  /// - currentPosition with timeout
  Future<Position?> _safeGetPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      // 1) fastest fallback
      final last = await Geolocator.getLastKnownPosition();

      // 2) try precise with timeout
      try {
        final current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(timeout);
        return current;
      } catch (_) {
        return last;
      }
    } catch (_) {
      return null;
    }
  }

  /// ✅ HTTP notify with Bearer token
  /// - No throw outside (ke submit flow reset nakone)
  Future<void> _sendNotification({
    required String title,
    required String body,
    required String lostDogId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ sendNotification: No authenticated user");
        return;
      }

      final idToken = await user.getIdToken(); // ✅ NOT forced refresh

      final response = await http.post(
        Uri.parse(
          'https://europe-west3-barkymatches-new.cloudfunctions.net/sendLostFoundNotificationHttp',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'lostDogId': lostDogId,
        }),
      );

      debugPrint("HTTP status: ${response.statusCode}");
      debugPrint("HTTP body: ${response.body}");
    } catch (e, s) {
      debugPrint("❌ sendNotification ERROR: $e");
      debugPrint("$s");
      // intentionally swallow
    }
  }

  Future<void> _submitReport() async {
  AuthTrap.mark('lostdog_submit_pressed');

  if (kDebugMode) {
    debugPrint(
      'LostDogReportPage - Submitting report, _currentPosition: $_currentPosition, _isSubmitting: $_isSubmitting',
    );
  }

  if (_isSubmitting) return;

  if (!(_formKey.currentState?.validate() ?? false)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Please complete all required fields correctly."),
      backgroundColor: Colors.red,
    ),
  );
  return;
}

  setState(() => _isSubmitting = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }

    // ✅ Always get safe position at submit time (avoid null / long hangs)
    final pos = await _safeGetPosition(timeout: const Duration(seconds: 8));
    final finalPos = pos ?? _currentPosition ?? _defaultPosition();

    if (mounted) {
      setState(() {
        _currentPosition = finalPos;
      });
    }

    final lostDog = LostDog(

gender: _selectedGender,
healthStatus: _selectedHealthStatus,

      name: _nameController.text.trim(),
      breed: _selectedBreed!,
      color: _colorController.text.trim().isNotEmpty
          ? _colorController.text.trim()
          : null,
      weight: _weightController.text.trim().isNotEmpty
          ? _weightController.text.trim()
          : null,
      collarType: _selectedCollarType,
      clothingColor: _clothingColorController.text.trim().isNotEmpty
          ? _clothingColorController.text.trim()
          : null,
      lostLocation: _lostLocationController.text.trim(),
      contactInfo: {
  "type": _selectedContactType,
  "value": _contactInfoController.text.trim(),
},
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      latitude: finalPos.latitude,
      longitude: finalPos.longitude,
      reportedAt: DateTime.now(),
      reportedBy: user.uid,
      isFound: false,
    );

    if (kDebugMode) {
      debugPrint('LostDogReportPage - Submitting LostDog: $lostDog');
      debugPrint('LostDogReportPage - toMap: ${lostDog.toMap()}');
    }

    AuthTrap.mark('before_lostdog_firestore_add');
    debugPrint(
      '🧨 currentUser BEFORE add = ${FirebaseAuth.instance.currentUser?.uid ?? "NULL"}',
    );

    final docRef = await FirebaseFirestore.instance
        .collection('lost_dogs')
        .add(lostDog.toMap());

final imageUrl = await _uploadImage(docRef.id);

if (imageUrl != null) {
  await docRef.update({'imageUrl': imageUrl});
}

    if (kDebugMode) {
      debugPrint(
        'LostDogReportPage - Report submitted successfully with doc ID: ${docRef.id}',
      );
    }

    // ✅ IMPORTANT: await the HTTP call (no unawaited) to avoid lifecycle issues
    await _sendNotification(
      title: 'New Lost Dog Reported',
      body:
          '${lostDog.name} (${lostDog.breed}) has been reported lost near '
          '${lostDog.latitude}, ${lostDog.longitude}',
      lostDogId: docRef.id,
    );

    if (!mounted) return;

    // ✅ show snackbar safely (even if context not under a Scaffold)
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Lost dog reported successfully!')),
    );

    AuthTrap.mark('after_lostdog_http_200_before_tab_switch');
    debugPrint(
      '🧨 currentUser BEFORE tab switch = ${FirebaseAuth.instance.currentUser?.uid ?? "NULL"}',
    );

    // ✅ CRITICAL FIX: this page was opened via setCurrentTab, so DO NOT Navigator.pop
    // switch back to home (or any tab you want)
    context.read<AppState>().setCurrentTab(NavTab.home);
  } catch (e, s) {
    debugPrint('LostDogReportPage - Error submitting report: $e');
    debugPrint('$s');

    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Error submitting report: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _clothingColorController.dispose();
    _lostLocationController.dispose();
    _contactInfoController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _whiteDecoration(String label, {bool required = false}) {
    return InputDecoration(
      hintText: required ? '$label *' : label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTextField(
  TextEditingController controller,
  String label, {
  bool required = false,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
    return TextFormField(
      keyboardType: keyboardType,
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.black),
      decoration: _whiteDecoration(label, required: required),
      validator: required
          ? (value) =>
              value == null || value.isEmpty ? 'Please enter $label' : null
          : null,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: GoogleFonts.poppins(color: Colors.black54),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      iconEnabledColor: AppTheme.accent,
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  List<String> getDogBreeds(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return [
      localizations.breedAfghanHound,
      localizations.breedAiredaleTerrier,
      localizations.breedAkita,
      localizations.breedAlaskanMalamute,
      localizations.breedAmericanBulldog,
      localizations.breedAmericanPitBullTerrier,
      localizations.breedAustralianCattleDog,
      localizations.breedAustralianShepherd,
      localizations.breedBassetHound,
      localizations.breedBeagle,
      localizations.breedBelgianMalinois,
      localizations.breedBerneseMountainDog,
      localizations.breedBichonFrise,
      localizations.breedBloodhound,
      localizations.breedBorderCollie,
      localizations.breedBostonTerrier,
      localizations.breedBoxer,
      localizations.breedBulldog,
      localizations.breedBullmastiff,
      localizations.breedCairnTerrier,
      localizations.breedCaneCorso,
      localizations.breedCavalierKingCharlesSpaniel,
      localizations.breedChihuahua,
      localizations.breedChowChow,
      localizations.breedCockerSpaniel,
      localizations.breedCollie,
      localizations.breedDachshund,
      localizations.breedDalmatian,
      localizations.breedDobermanPinscher,
      localizations.breedEnglishSpringerSpaniel,
      localizations.breedFrenchBulldog,
      localizations.breedGermanShepherd,
      localizations.breedGermanShorthairedPointer,
      localizations.breedGoldenRetriever,
      localizations.breedGreatDane,
      localizations.breedGreatPyrenees,
      localizations.breedHavanese,
      localizations.breedIrishSetter,
      localizations.breedIrishWolfhound,
      localizations.breedJackRussellTerrier,
      localizations.breedLabradorRetriever,
      localizations.breedLhasaApso,
      localizations.breedMaltese,
      localizations.breedMastiff,
      localizations.breedMiniatureSchnauzer,
      localizations.breedNewfoundland,
      localizations.breedPapillon,
      localizations.breedPekingese,
      localizations.breedPomeranian,
      localizations.breedPoodle,
      localizations.breedPug,
      localizations.breedRottweiler,
      localizations.breedSaintBernard,
      localizations.breedSamoyed,
      localizations.breedShetlandSheepdog,
      localizations.breedShihTzu,
      localizations.breedSiberianHusky,
      localizations.breedStaffordshireBullTerrier,
      localizations.breedVizsla,
      localizations.breedWeimaraner,
      localizations.breedWestHighlandWhiteTerrier,
      localizations.breedYorkshireTerrier,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.card,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
  _nameController,
  "Missing Dog Name",
  required: true,
),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          value: _selectedBreed,
                          hint: localizations.selectBreedHint,
                          items: getDogBreeds(context),
                          onChanged: (value) =>
                              setState(() => _selectedBreed = value),
                          validator: (value) =>
                              value == null ? localizations.pleaseSelectBreed : null,
                        ),


const SizedBox(height: 16),

_buildDropdownField(
  value: _selectedGender,
  validator: (value) =>
    value == null ? "Select gender" : null,
  hint: "Select Gender",
  items: _genders,
  onChanged: (value) => setState(() => _selectedGender = value),
),

const SizedBox(height: 16),

_buildDropdownField(
  value: _selectedHealthStatus,
  hint: "Select Health Status",
  items: _healthStatuses,
  onChanged: (value) => setState(() => _selectedHealthStatus = value),
),
                        const SizedBox(height: 16),

                        
                        _buildTextField(_colorController, localizations.colorLabel),
                        const SizedBox(height: 16),
                        _buildTextField(
  _weightController,
  localizations.weightLabel,
  keyboardType: TextInputType.number,
),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          value: _selectedCollarType,
                          hint: localizations.selectCollarTypeHint,
                          items: _collarTypes,
                          onChanged: (value) =>
                              setState(() => _selectedCollarType = value),
                        ),

                        const SizedBox(height: 16),
                        _buildTextField(
                          _clothingColorController,
                          localizations.clothingColorLabel,
                        ),

                        const SizedBox(height: 16),
                        Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    _buildTextField(
      _lostLocationController,
      localizations.lostLocationLabel,
      required: true,
    ),

    const SizedBox(height: 8),

    OutlinedButton.icon(
      onPressed: () async {
  final current = _currentPosition ?? _defaultPosition();

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MapPickerPage(
        initialLocation: LatLng(current.latitude, current.longitude),
      ),
    ),
  );

  if (result != null && result is LatLng) {
    setState(() {
      _lostLocationController.text =
          "${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}";
    });
  }
},
      icon: const Icon(Icons.map),
      label: const Text("Select from Map"),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent,
        side: BorderSide(color: AppTheme.accent),
      ),
    ),
  ],
),
                        const SizedBox(height: 16),
                        _buildDropdownField(
  value: _selectedContactType,
  hint: "Select Contact Type",
  items: _contactTypes,
  onChanged: (value) =>
      setState(() => _selectedContactType = value),
  validator: (value) =>
      value == null ? "Please select contact type" : null,
),

const SizedBox(height: 12),

TextFormField(
  controller: _contactInfoController,
  keyboardType: _selectedContactType == "Phone"
      ? TextInputType.phone
      : TextInputType.emailAddress,
  decoration: _whiteDecoration("Enter Contact Detail", required: true),
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return "Contact detail required";
    }

    if (_selectedContactType == "Phone") {
      final phoneRegex = RegExp(r'^\d{10,15}$');
      if (!phoneRegex.hasMatch(value.trim())) {
        return "Phone must be 10-15 digits";
      }
    }

    if (_selectedContactType == "Email") {
      final emailRegex =
          RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(value.trim())) {
        return "Invalid email format";
      }
    }

    return null;
  },
),
const SizedBox(height: 12),

GestureDetector(
  onTap: _pickImage,
  child: Container(
    height: 150,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: _selectedImage == null
        ? const Center(child: Text("Tap to select image"))
        : ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
  ),
),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _descriptionController,
                          localizations.descriptionLabel,
                          maxLines: 3,
                        ),

                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  localizations.reportLostDogMenuItem,
                                  style: AppTheme.body(),
                                ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isSubmitting)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
}

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Location")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: 14,
        ),
        onTap: (latLng) {
          setState(() {
            _selectedLocation = latLng;
          });
        },
        markers: {
          Marker(
            markerId: const MarkerId("selected"),
            position: _selectedLocation,
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context, _selectedLocation);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
  
}
