import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class EditMedicalProfilePage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final Map<String, dynamic> initialData;

  const EditMedicalProfilePage({
    super.key,
    required this.businessId,
    required this.patientId,
    required this.initialData,
  });

  @override
  State<EditMedicalProfilePage> createState() => _EditMedicalProfilePageState();
}

class _EditMedicalProfilePageState extends State<EditMedicalProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _petNameController;
  late final TextEditingController _weightController;
  late final TextEditingController _microchipController;
  late final TextEditingController _passportController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _chronicDiseasesController;

  Map<String, dynamic> _patientData = {};
  Map<String, dynamic> _dogData = {};
  String _bloodType = 'Unknown';
  bool _loading = true;
  bool _saving = false;

  bool get _isOwnerView => widget.businessId == 'owner_medical_record';

  // TODO: medications should be stored in patients/{patientId}/medications
  // TODO: lab results should be stored in patients/{patientId}/lab_results
  // TODO: documents/xray/pdf should be stored in patients/{patientId}/documents

  @override
  void initState() {
    super.initState();

    _patientData = Map<String, dynamic>.from(widget.initialData);
    _petNameController = TextEditingController(
      text: _readFirst(['petName', 'name']),
    );
    _weightController = TextEditingController(text: _readFirst(['weight']));
    _microchipController = TextEditingController(
      text: _readFirst(['microchipNumber', 'microchip']),
    );
    _passportController = TextEditingController(
      text: _readFirst(['passportNumber', 'passport', 'importId']),
    );
    _allergiesController = TextEditingController(
      text: _readFirst(['allergies']),
    );
    _chronicDiseasesController = TextEditingController(
      text: _readFirst(['chronicDiseases']),
    );
    _bloodType = _resolveBloodType();
    _loadRecordData();
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _weightController.dispose();
    _microchipController.dispose();
    _passportController.dispose();
    _allergiesController.dispose();
    _chronicDiseasesController.dispose();
    super.dispose();
  }

  Future<void> _loadRecordData() async {
    try {
      if (_isOwnerView) {
        final dogSnap = await FirebaseFirestore.instance
            .collection('dogs')
            .doc(widget.patientId)
            .get();

        if (!mounted) return;
        setState(() {
          _dogData = dogSnap.data() ?? {};
          _patientData = {...widget.initialData, ..._dogData};
          _syncControllersFromData();
          _loading = false;
        });
        return;
      }

      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);
      final patientSnap = await patientRef.get();
      final patientData = patientSnap.data() ?? widget.initialData;
      final petId =
          _stringOrNull(patientData['petId']) ??
          _stringOrNull(widget.initialData['petId']);
      Map<String, dynamic> dogData = {};

      if (petId != null) {
        final dogSnap = await FirebaseFirestore.instance
            .collection('dogs')
            .doc(petId)
            .get();
        dogData = dogSnap.data() ?? {};
      }

      if (!mounted) return;
      setState(() {
        _patientData = patientData;
        _dogData = dogData;
        _syncControllersFromData();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ MEDICAL PROFILE LOAD ERROR: $e');

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _syncControllersFromData() {
    _petNameController.text = _readFirst(['petName', 'name']);
    _weightController.text = _readFirst(['weight']);
    _microchipController.text = _readFirst(['microchipNumber', 'microchip']);
    _passportController.text = _readFirst([
      'passportNumber',
      'passport',
      'importId',
    ]);
    _allergiesController.text = _readFirst(['allergies']);
    _chronicDiseasesController.text = _readFirst(['chronicDiseases']);
    _bloodType = _resolveBloodType();
  }

  String _readFirst(List<String> keys, {String fallback = ''}) {
    for (final source in [_patientData, widget.initialData, _dogData]) {
      for (final key in keys) {
        final value = source[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return fallback;
  }

  String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _display(List<String> keys, {String fallback = 'Not recorded'}) {
    final value = _readFirst(keys);
    return value.isEmpty ? fallback : value;
  }

  String _species() => _display(['petType', 'species', 'type']);

  String _gender() => _display(['gender', 'sex']);

  String _age() {
    final age = _readFirst(['age']);
    if (age.isNotEmpty) return age;

    final birthDate = _dateFromValue(_firstRaw(['birthDate']));
    if (birthDate == null) return 'Not recorded';

    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (DateTime(now.year, birthDate.month, birthDate.day).isAfter(now)) {
      years--;
    }

    if (years <= 0) return '< 1 year';
    if (years == 1) return '1 year';
    return '$years years';
  }

  dynamic _firstRaw(List<String> keys) {
    for (final source in [_patientData, widget.initialData, _dogData]) {
      for (final key in keys) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> get _bloodTypeOptions {
    final species = _readFirst(['petType', 'species', 'type']).toLowerCase();
    final base = switch (species) {
      'dog' => <String>[
        'DEA 1+',
        'DEA 1-',
        'DEA 3',
        'DEA 4',
        'DEA 5',
        'DEA 7',
        'Unknown',
      ],
      'cat' => <String>['A', 'B', 'AB', 'Unknown'],
      _ => <String>['Unknown'],
    };

    final saved = _readFirst(['bloodType']);
    if (saved.isNotEmpty && !base.contains(saved)) {
      return [saved, ...base];
    }

    return base;
  }

  String _resolveBloodType() {
    final saved = _readFirst(['bloodType']);
    return saved.isEmpty ? 'Unknown' : saved;
  }

  Future<void> _saveMedicalProfile() async {
    if (_isOwnerView) return;
    if (!_formKey.currentState!.validate()) return;

    final microchip = _microchipController.text.trim();
    if (microchip.isNotEmpty && microchip.length != 15) {
      final confirmed = await _confirmMicrochipOverride(microchip);
      if (!confirmed) return;
    }

    debugPrint('🩺 MEDICAL PROFILE SAVE START');

    setState(() {
      _saving = true;
    });

    try {
      final patientRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('patients')
          .doc(widget.patientId);

      final petName = _petNameController.text.trim();
      final weightText = _weightController.text.trim().replaceAll(',', '.');
      final updateData = <String, dynamic>{
        'petName': petName,
        'name': petName,
        'weight': weightText.isEmpty ? null : double.parse(weightText),
        'microchipNumber': microchip,
        'bloodType': _bloodType,
        'allergies': _allergiesController.text.trim(),
        'chronicDiseases': _chronicDiseasesController.text.trim(),
        'passportNumber': _passportController.text.trim(),
        'medicalProfileUpdatedAt': FieldValue.serverTimestamp(),
        'medicalProfileUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
        'medicalProfileUpdatedByName': FirebaseAuth
            .instance
            .currentUser
            ?.displayName
            ?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await patientRef.update(updateData);
      debugPrint('🩺 MEDICAL PROFILE UPDATED IN PATIENT');

      final patientSnap = await patientRef.get();
      final petId = _stringOrNull(patientSnap.data()?['petId']);

      if (petId != null) {
        await FirebaseFirestore.instance
            .collection('dogs')
            .doc(petId)
            .update(updateData);
        debugPrint('🩺 DOG MEDICAL PROFILE MIRROR UPDATED');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medical profile updated')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ MEDICAL PROFILE UPDATE ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _confirmMicrochipOverride(String microchip) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Microchip Number'),
          content: Text(
            'ISO 11784/11785 microchip numbers are normally 15 digits. '
            '"$microchip" has ${microchip.length} digits. Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Anyway'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  String _formatTimestamp(dynamic value) {
    final date = _dateFromValue(value);
    if (date == null) return 'Not recorded';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.h3(color: AppTheme.card)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: AppTheme.caption()),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _editableField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? suffixText,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isOwnerView,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textAlignVertical: TextAlignVertical.top,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: _inputDecoration(
        label: label,
        hintText: hintText,
        suffixText: suffixText,
        fillColor: _isOwnerView ? Colors.grey.shade100 : Colors.white,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hintText,
    String? suffixText,
    Color? fillColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      counterText: '',
      filled: true,
      fillColor: fillColor ?? Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.card, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }

  Widget _identityPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.card),
          const SizedBox(width: 6),
          Text('$label: ', style: AppTheme.caption(weight: FontWeight.w700)),
          Text(value, style: AppTheme.caption()),
        ],
      ),
    );
  }

  Widget _readOnlyRow({
    required String label,
    required String value,
    IconData icon = Icons.lock_outline,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTheme.caption())),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.body(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTheme.caption())),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.body(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTheme.body(weight: FontWeight.w600)),
          ),
          Text('Coming Soon', style: AppTheme.caption(color: Colors.black45)),
        ],
      ),
    );
  }

  String get _updatedBy {
    final value = _readFirst(['medicalProfileUpdatedByName', 'vetName']);
    return value.isEmpty ? 'Veterinarian' : value;
  }

  String get _recordSource {
    final source = _readFirst(['recordSource', 'source']).toLowerCase();
    if (source.contains('owner') || _isOwnerView) return 'Owner Imported';
    return 'Clinic Record';
  }

  @override
  Widget build(BuildContext context) {
    final lastUpdated = _firstRaw(['medicalProfileUpdatedAt', 'updatedAt']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.card,
        title: const Text('Medical Profile'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionCard(
                        title: 'Patient Identity',
                        subtitle:
                            'Stable identifiers used by the clinic record.',
                        children: [
                          _editableField(
                            controller: _petNameController,
                            label: 'Pet Name',
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'Pet name is required';
                              if (text.length < 2) {
                                return 'Pet name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _identityPill(
                                icon: Icons.pets_outlined,
                                label: 'Species',
                                value: _species(),
                              ),
                              _identityPill(
                                icon: Icons.badge_outlined,
                                label: 'Breed',
                                value: _display(['breed']),
                              ),
                              _identityPill(
                                icon: Icons.wc_outlined,
                                label: 'Gender',
                                value: _gender(),
                              ),
                              _identityPill(
                                icon: Icons.cake_outlined,
                                label: 'Age',
                                value: _age(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Medical Identifiers',
                        children: [
                          _editableField(
                            controller: _microchipController,
                            label: 'Microchip Number',
                            hintText: 'ISO 11784/11785',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              if (!RegExp(r'^\d+$').hasMatch(text)) {
                                return 'Microchip number must contain digits only';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _editableField(
                            controller: _passportController,
                            label: 'Passport / Import ID',
                            maxLength: 40,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _bloodType,
                            isExpanded: true,
                            decoration: _inputDecoration(label: 'Blood Type'),
                            items: _bloodTypeOptions
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: _isOwnerView
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _bloodType = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Health Summary',
                        subtitle:
                            'High-level clinical summary, not visit history.',
                        children: [
                          _editableField(
                            controller: _weightController,
                            label: 'Weight',
                            suffixText: 'kg',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[,.]?\d*'),
                              ),
                            ],
                            validator: (value) {
                              final text = (value ?? '').trim().replaceAll(
                                ',',
                                '.',
                              );
                              if (text.isEmpty) return null;

                              final parsed = double.tryParse(text);
                              if (parsed == null) {
                                return 'Weight must be a valid number';
                              }
                              if (parsed <= 0 || parsed >= 200) {
                                return 'Weight must be greater than 0 and less than 200';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _editableField(
                            controller: _allergiesController,
                            label: 'Allergies',
                            hintText:
                                'Known drug, food, or environmental allergies',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _editableField(
                            controller: _chronicDiseasesController,
                            label: 'Chronic Diseases',
                            hintText:
                                'Long-term diagnoses or recurring conditions',
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Owner & Emergency Contacts',
                        subtitle:
                            'Read-only contact details linked to this medical record.',
                        children: [
                          _readOnlyRow(
                            label: 'Owner Name',
                            value: _display(['ownerName', 'ownerDisplayName']),
                          ),
                          _readOnlyRow(
                            label: 'Owner Phone',
                            value: _display([
                              'ownerPhone',
                              'phone',
                              'ownerPhoneNumber',
                            ]),
                          ),
                          _readOnlyRow(
                            label: 'Emergency Contact',
                            value: _display(['emergencyContact']),
                          ),
                          _readOnlyRow(
                            label: 'Emergency Phone',
                            value: _display(['emergencyPhone']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Future EMR Modules',
                        subtitle:
                            'Structured medical history will live outside the main profile.',
                        children: [
                          _moduleCard('Medications'),
                          const SizedBox(height: 8),
                          _moduleCard('Lab Results'),
                          const SizedBox(height: 8),
                          _moduleCard('Imaging'),
                          const SizedBox(height: 8),
                          _moduleCard('Surgeries'),
                          const SizedBox(height: 8),
                          _moduleCard('Documents'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Audit',
                        children: [
                          _auditRow(
                            'Last Medical Update',
                            _formatTimestamp(lastUpdated),
                          ),
                          _auditRow('Updated By', _updatedBy),
                          _auditRow('Record Source', _recordSource),
                        ],
                      ),
                      if (!_isOwnerView) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveMedicalProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.card,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save Medical Profile',
                                    style: AppTheme.button(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
