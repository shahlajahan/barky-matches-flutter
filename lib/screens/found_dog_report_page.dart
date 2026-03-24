import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/found_dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class FoundDogReportPage extends StatefulWidget {
  const FoundDogReportPage({super.key});

  @override
  _FoundDogReportPageState createState() => _FoundDogReportPageState();
}

class _FoundDogReportPageState extends State<FoundDogReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedBreed;
  final _colorController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedCollarType;
  final _clothingColorController = TextEditingController();
  final _foundLocationController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _descriptionController = TextEditingController();
  Position? _currentPosition;
  bool _isSubmitting = false;
  
String? _selectedContactType;
File? _selectedImage;
bool _isPickingImage = false;
bool _isUploadingImage = false;

final List<String> _contactTypes = [
  "Phone",
  "Email",
  "Instagram",
];
  final List<String> _collarTypes = ['Leather', 'Nylon', 'Chain', 'Other'];

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
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentPosition = Position(
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
          });
        }
        if (kDebugMode) print('FoundDogReportPage - Using default position due to disabled location services');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _currentPosition = Position(
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
            });
          }
          if (kDebugMode) print('FoundDogReportPage - Using default position due to permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      if (kDebugMode) print('FoundDogReportPage - Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = Position(
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
        });
      }
      if (kDebugMode) print('FoundDogReportPage - Error getting location: $e, using default position');
    }
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
  if (user == null || _selectedImage == null) return null;

  try {
    setState(() => _isUploadingImage = true);

    final ref = FirebaseStorage.instance
        .ref()
        .child('found_dogs/${user.uid}/$docId.jpg');

    await ref.putFile(_selectedImage!);
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint("Image upload error: $e");
    return null;
  } finally {
    setState(() => _isUploadingImage = false);
  }
}

  Future<void> _sendNotification({
  required String title,
  required String body,
  required String foundDogId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();

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
        'foundDogId': foundDogId,
      }),
    );

    debugPrint("HTTP status: ${response.statusCode}");
    debugPrint("HTTP body: ${response.body}");
  } catch (e) {
    debugPrint("Notification error: $e");
  }
}

  Future<void> _submitReport() async {
    if (kDebugMode) print('FoundDogReportPage - Submitting report, _currentPosition: $_currentPosition, _isSubmitting: $_isSubmitting');
    if (_formKey.currentState!.validate() && !_isSubmitting) {
      setState(() => _isSubmitting = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('No user signed in');

        final foundDog = FoundDog(
          name: _nameController.text.trim(),
          breed: _selectedBreed!,
          color: _colorController.text.trim().isNotEmpty ? _colorController.text.trim() : null,
          weight: _weightController.text.trim().isNotEmpty ? _weightController.text.trim() : null,
          collarType: _selectedCollarType,
          clothingColor: _clothingColorController.text.trim().isNotEmpty ? _clothingColorController.text.trim() : null,
          foundLocation: _foundLocationController.text.trim(),
          contactInfo: {
  "type": _selectedContactType,
  "value": _contactInfoController.text.trim(),
},
          description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          latitude: _currentPosition?.latitude ?? 41.0103,
          longitude: _currentPosition?.longitude ?? 28.6724,
          reportedAt: DateTime.now(),
          reportedBy: user.uid,
          isClaimed: false,
        );

        if (kDebugMode) {
          print('FoundDogReportPage - Submitting FoundDog: $foundDog');
          print('FoundDogReportPage - toMap: ${foundDog.toMap()}');
        }

        final docRef = await FirebaseFirestore.instance.collection('found_dogs').add(foundDog.toMap());

        final imageUrl = await _uploadImage(docRef.id);

if (imageUrl != null) {
  await docRef.update({'imageUrl': imageUrl});
}
        if (kDebugMode) print('FoundDogReportPage - Report submitted successfully with doc ID: ${docRef.id}');

        await _sendNotification(
  title: 'Found Dog Reported',
  body:
      '${foundDog.name} (${foundDog.breed}) has been found near '
      '${foundDog.latitude}, ${foundDog.longitude}',
  foundDogId: docRef.id,
);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Found dog reported successfully!')),
        );
        context.read<AppState>().setCurrentTab(NavTab.home);
      } catch (e) {
        if (kDebugMode) print('FoundDogReportPage - Error submitting report: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      if (kDebugMode) print('FoundDogReportPage - Form validation failed or submitting');
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _clothingColorController.dispose();
    _foundLocationController.dispose();
    _contactInfoController.dispose();
    _descriptionController.dispose();
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

  List<String> getDogTraits(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return [
      localizations.traitEnergetic,
      localizations.traitPlayful,
      localizations.traitCalm,
      localizations.traitLoyal,
      localizations.traitFriendly,
      localizations.traitProtective,
      localizations.traitIntelligent,
      localizations.traitAffectionate,
      localizations.traitCurious,
      localizations.traitIndependent,
      localizations.traitShy,
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
                        localizations.nameLabel,
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
                            value == null
                                ? localizations.pleaseSelectBreed
                                : null,
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        _colorController,
                        localizations.colorLabel,
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        _weightController,
                        localizations.weightLabel,
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
      _foundLocationController,
      localizations.foundLocationLabel,
      required: true,
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: () async {
        final current = _currentPosition ?? _defaultPosition();

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FoundMapPickerPage(
              initialLocation: LatLng(
                current.latitude,
                current.longitude,
              ),
            ),
          ),
        );

        if (result != null && result is LatLng) {
          setState(() {
            _foundLocationController.text =
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
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(value.trim())) {
        return "Invalid email format";
      }
    }

    return null;
  },
),

                      const SizedBox(height: 16),

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
const SizedBox(height: 20),
                      _buildTextField(
                        _descriptionController,
                        localizations.descriptionLabel,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed:
                            _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.black,
                          minimumSize:
                              const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                localizations
                                    .reportFoundDogMenuItem,
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
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _whiteDecoration(
  String label, {
  bool required = false,
}) {
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
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    style: GoogleFonts.poppins(color: Colors.black),
    decoration: _whiteDecoration(label, required: required),
    validator: required
        ? (value) =>
            value == null || value.isEmpty
                ? 'Please enter $label'
                : null
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
}
class FoundMapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const FoundMapPickerPage({
    super.key,
    required this.initialLocation,
  });

  @override
  State<FoundMapPickerPage> createState() =>
      _FoundMapPickerPageState();
}

class _FoundMapPickerPageState
    extends State<FoundMapPickerPage> {
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