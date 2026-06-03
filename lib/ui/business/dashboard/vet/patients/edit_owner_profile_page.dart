import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/owner_profile_snapshot.dart';

class EditOwnerProfilePage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final Map<String, dynamic> initialData;

  const EditOwnerProfilePage({
    super.key,
    required this.businessId,
    required this.patientId,
    required this.initialData,
  });

  @override
  State<EditOwnerProfilePage> createState() => _EditOwnerProfilePageState();
}

class _EditOwnerProfilePageState extends State<EditOwnerProfilePage> {
  late final TextEditingController _ownerNameController;
  late final TextEditingController _ownerPhoneController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _addressController;

  bool _isSaving = false;

  bool get _isOwnerMedicalMode => widget.businessId == 'owner_medical_record';

  Map<String, dynamic> get ownerProfile {
    final raw = <String, dynamic>{};

    void mergeValue(String key, dynamic value) {
      final text = ownerSnapshotString(value);
      if (text == null) return;

      raw[key] ??= text;
    }

    void mergeSource(dynamic source) {
      if (source is! Map) return;

      final map = Map<String, dynamic>.from(source);

      mergeValue(
        'ownerName',
        map['ownerName'] ??
            map['ownerDisplayName'] ??
            map['displayName'] ??
            map['name'] ??
            map['fullName'] ??
            map['userName'] ??
            map['username'],
      );
      mergeValue(
        'ownerPhone',
        map['ownerPhone'] ??
            map['phone'] ??
            map['phoneNumber'] ??
            map['userPhone'],
      );
      mergeValue('emergencyContact', map['emergencyContact']);
      mergeValue(
        'emergencyPhone',
        map['emergencyPhone'] ?? map['emergencyContactNumber'],
      );
      mergeValue('city', map['city']);
      mergeValue('district', map['district']);
      mergeValue('address', map['address'] ?? map['registrationAddress']);
    }

    mergeSource(widget.initialData['effectiveOwnerProfile']);
    mergeSource(widget.initialData['resolvedOwnerProfile']);
    mergeSource(widget.initialData['ownerProfile']);
    mergeSource(widget.initialData);

    return completeOwnerProfileSnapshot(raw);
  }

  @override
  void initState() {
    super.initState();

    _ownerNameController = TextEditingController(
      text: ownerProfile['ownerName'] ?? '',
    );

    _ownerPhoneController = TextEditingController(
      text: ownerProfile['ownerPhone'] ?? '',
    );

    _emergencyContactController = TextEditingController(
      text: ownerProfile['emergencyContact'] ?? '',
    );

    _emergencyPhoneController = TextEditingController(
      text: ownerProfile['emergencyPhone'] ?? '',
    );

    _cityController = TextEditingController(text: ownerProfile['city'] ?? '');

    _districtController = TextEditingController(
      text: ownerProfile['district'] ?? '',
    );

    _addressController = TextEditingController(
      text: ownerProfile['address'] ?? '',
    );
    debugPrint('OWNER PROFILE INIT: $ownerProfile');
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    return value
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  bool _isValidTurkishPhone(String value) {
    final normalized = _normalizePhone(value);

    return RegExp(r'^\+90[0-9]{10}$').hasMatch(normalized);
  }

  bool _isValidName(String value) {
    final text = value.trim();

    if (text.isEmpty) return true;

    return RegExp(r'^[a-zA-ZçÇğĞıİöÖşŞüÜ\s]+$').hasMatch(text);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ownerPhone = _normalizePhone(_ownerPhoneController.text);
    final emergencyPhone = _normalizePhone(_emergencyPhoneController.text);
    final ownerName = ownerSnapshotString(_ownerNameController.text) ?? '';
    final emergencyContact =
        ownerSnapshotString(_emergencyContactController.text) ?? '';
    final city = ownerSnapshotString(_cityController.text) ?? '';
    final district = ownerSnapshotString(_districtController.text) ?? '';
    final address = ownerSnapshotString(_addressController.text) ?? '';

    if (_isSaving) return;

    // PHONE VALIDATION
    if (ownerPhone.isNotEmpty && !_isValidTurkishPhone(ownerPhone)) {
      _showError('Owner phone format:\n+905XXXXXXXXX');
      return;
    }

    if (emergencyPhone.isNotEmpty && !_isValidTurkishPhone(emergencyPhone)) {
      _showError('Emergency phone format:\n+905XXXXXXXXX');
      return;
    }

    // NAME VALIDATION
    if (!_isValidName(emergencyContact)) {
      _showError('Emergency contact must contain only name');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedOwnerProfile = Map<String, dynamic>.from(ownerProfile)
      ..['ownerName'] = ownerName
      ..['ownerPhone'] = ownerPhone
      ..['city'] = city
      ..['district'] = district
      ..['address'] = address
      ..['emergencyContact'] = emergencyContact
      ..['emergencyPhone'] = emergencyPhone;

    updatedOwnerProfile['updatedAt'] = FieldValue.serverTimestamp();
    updatedOwnerProfile['profileVersion'] = 1;

    try {
      final firestore = FirebaseFirestore.instance;

      final dogId =
          widget.initialData['petId']?.toString().trim().isNotEmpty == true
          ? widget.initialData['petId'].toString().trim()
          : widget.patientId;

      final dogSnap = await firestore.collection('dogs').doc(dogId).get();
      final dogData = dogSnap.data() ?? {};

      if (!mounted) return;

      final ownerUid =
          _stringOrNull(dogData['ownerUid']) ??
          _stringOrNull(dogData['ownerId']) ??
          _stringOrNull(dogData['userId']) ??
          _stringOrNull(widget.initialData['ownerUid']) ??
          _stringOrNull(widget.initialData['ownerId']) ??
          _stringOrNull(widget.initialData['userId']) ??
          FirebaseAuth.instance.currentUser?.uid;

      final userUpdateData = <String, dynamic>{
        'city': city,
        'district': district,
        'address': address,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
        'profileVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final ownerName = updatedOwnerProfile['ownerName']?.toString().trim();
      if (ownerName != null && ownerName.isNotEmpty) {
        userUpdateData['displayName'] = ownerName;
      }

      final safePhone = updatedOwnerProfile['ownerPhone']?.toString().trim();
      if (safePhone != null && safePhone.isNotEmpty) {
        userUpdateData['phone'] = safePhone;
      }

      if (_isOwnerMedicalMode) {
        debugPrint('OWNER MEDICAL SAVE MODE ACTIVE');
        debugPrint('WRITING DOG DOC ONLY');
        debugPrint('SKIPPING BUSINESS MIRROR');
        debugPrint('SKIPPING PATIENT MIRROR');

        await firestore.collection('dogs').doc(dogId).set({
          'ownerProfile': updatedOwnerProfile,
          'ownerProfileUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('OWNER PROFILE DOG UPDATED');

        if (ownerUid != null) {
          debugPrint('🩺 USER UPDATE PAYLOAD: $userUpdateData');
          debugPrint('USER DOC WRITE UID: $ownerUid');
          await firestore
              .collection('users')
              .doc(ownerUid)
              .set(userUpdateData, SetOptions(merge: true));
          debugPrint('OWNER PROFILE USER UPDATED');
        }

        debugPrint('PATIENT OWNER SNAPSHOT SAVED');

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Owner profile updated')));

        Navigator.pop(context);
        return;
      }
      final batch = firestore.batch();

      final dogRef = firestore.collection('dogs').doc(dogId);

      batch.set(dogRef, {
        'ownerProfile': updatedOwnerProfile,
        'ownerProfileUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('OWNER PROFILE DOG UPDATED');

      if (ownerUid != null) {
        batch.set(
          firestore.collection('users').doc(ownerUid),
          userUpdateData,
          SetOptions(merge: true),
        );
        debugPrint('OWNER PROFILE USER UPDATED');
      }

      final currentPatientRef = firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);

      batch.set(currentPatientRef, {
        'ownerProfile': updatedOwnerProfile,
        'ownerProfileUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final mirrors = await firestore
          .collectionGroup('patients')
          .where('petId', isEqualTo: dogId)
          .get();

      for (final doc in mirrors.docs) {
        batch.set(doc.reference, {
          'ownerProfile': updatedOwnerProfile,
          'ownerProfileUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      debugPrint('PATIENT OWNER SNAPSHOT SAVED');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Owner profile updated')));

      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ OWNER PROFILE SAVE ERROR: $e');
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _stringOrNull(dynamic value) {
    return ownerSnapshotString(value);
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,

      labelStyle: const TextStyle(fontSize: 14),

      prefixIcon: Icon(icon, size: 20),

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9F1452), width: 1.4),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,

        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),

        decoration: _inputDecoration(
          label: label,
          icon: icon ?? LucideIcons.circle,
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9F1452),
            ),
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EEF1),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF9F1452),

        title: const Text(
          'Owner Profile',

          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),

          child: Column(
            children: [
              // OWNER
              _section(
                title: 'Owner Identity',

                child: Column(
                  children: [
                    _field(
                      label: 'Owner Name',
                      controller: _ownerNameController,
                      icon: LucideIcons.user,
                    ),

                    _field(
                      label: 'Phone',
                      controller: _ownerPhoneController,
                      keyboardType: TextInputType.phone,
                      icon: LucideIcons.phone,
                    ),
                  ],
                ),
              ),

              // EMERGENCY
              _section(
                title: 'Emergency Contact',

                child: Column(
                  children: [
                    _field(
                      label: 'Emergency Contact Name',

                      controller: _emergencyContactController,

                      icon: LucideIcons.shield,
                    ),

                    _field(
                      label: 'Emergency Phone',

                      controller: _emergencyPhoneController,

                      keyboardType: TextInputType.phone,

                      icon: LucideIcons.phoneCall,
                    ),
                  ],
                ),
              ),

              // LOCATION
              _section(
                title: 'Location',

                child: Column(
                  children: [
                    _field(
                      label: 'City',
                      controller: _cityController,
                      icon: LucideIcons.mapPin,
                    ),

                    _field(
                      label: 'District',
                      controller: _districtController,
                      icon: LucideIcons.map,
                    ),

                    _field(
                      label: 'Address',
                      controller: _addressController,
                      maxLines: 3,
                      icon: LucideIcons.home,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,

                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 20),

                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Owner Profile',

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9F1452),

                    foregroundColor: Colors.white,

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
