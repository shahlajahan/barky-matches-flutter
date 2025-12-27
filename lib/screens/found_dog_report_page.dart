import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/found_dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';


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

  final List<String> _collarTypes = ['Leather', 'Nylon', 'Chain', 'Other'];

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

  Future<void> _sendNotification(String title, String body, String foundDogId) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
    try {
      final callable = functions.httpsCallable('sendNotification');
      await callable.call(<String, dynamic>{
        'title': title,
        'body': body,
        'foundDogId': foundDogId,
      });
      if (kDebugMode) print('FoundDogReportPage - Notification sent successfully via Cloud Function for foundDogId: $foundDogId');
    } catch (e) {
      if (kDebugMode) print('FoundDogReportPage - Error sending notification via Cloud Function: $e');
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
          contactInfo: _contactInfoController.text.trim(),
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
        if (kDebugMode) print('FoundDogReportPage - Report submitted successfully with doc ID: ${docRef.id}');

        await _sendNotification(
          'Found Dog Reported',
          '${foundDog.name} (${foundDog.breed}) has been found near ${foundDog.latitude}, ${foundDog.longitude}',
          docRef.id,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Found dog reported successfully!')),
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.reportFoundDogMenuItem,
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFC107),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFC107)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(_nameController, localizations.nameLabel, required: true),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedBreed,
                        hint: localizations.selectBreedHint,
                        items: getDogBreeds(context),
                        onChanged: (value) => setState(() => _selectedBreed = value),
                        validator: (value) => value == null ? localizations.pleaseSelectBreed : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_colorController, localizations.colorLabel),
                      const SizedBox(height: 16),
                      _buildTextField(_weightController, localizations.weightLabel),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        value: _selectedCollarType,
                        hint: localizations.selectCollarTypeHint,
                        items: _collarTypes,
                        onChanged: (value) => setState(() => _selectedCollarType = value),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_clothingColorController, localizations.clothingColorLabel),
                      const SizedBox(height: 16),
                      _buildTextField(_foundLocationController, localizations.foundLocationLabel, required: true),
                      const SizedBox(height: 16),
                      _buildTextField(_contactInfoController, localizations.contactInfoLabel, required: true),
                      const SizedBox(height: 16),
                      _buildTextField(_descriptionController, localizations.descriptionLabel, maxLines: 3),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFC107),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Color(0xFFFFC107))
                            : Text(
                                localizations.reportFoundDogMenuItem,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFC107),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFFFFC107),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.pink[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: GoogleFonts.poppins(
        color: const Color(0xFFFFC107),
        fontSize: 16,
      ),
      maxLines: maxLines,
      validator: required
          ? (value) => value == null || value.isEmpty
              ? 'لطفاً $label را وارد کنید'
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
      initialValue: value,
      hint: Text(
        hint,
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFC107),
          fontSize: 16,
        ),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.pink[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: Colors.pinkAccent,
      style: GoogleFonts.poppins(
        color: const Color(0xFFFFC107),
        fontSize: 16,
      ),
      iconEnabledColor: const Color(0xFFFFC107),
      menuMaxHeight: 300,
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFC107),
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}