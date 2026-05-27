import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barky_matches_fixed/models/business_draft.dart';

class PetTaxiRegistrationDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  const PetTaxiRegistrationDetailsPage({super.key, required this.baseDraft});

  @override
  State<PetTaxiRegistrationDetailsPage> createState() =>
      _PetTaxiRegistrationDetailsPageState();
}

class _PetTaxiRegistrationDetailsPageState
    extends State<PetTaxiRegistrationDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _petSafetyConfirmed = false;
  bool _hygieneConfirmed = false;
  bool _driverLicenseValidConfirmed = false;
  bool _vehicleRegistrationConfirmed = false;
  bool _trafficInsuranceConfirmed = false;
  bool _taxResponsibilityConfirmed = false;
  bool _transportRulesConfirmed = false;

  final _driverName = TextEditingController();
  final _driverPhone = TextEditingController();
  final _vehiclePlate = TextEditingController();

  final _vehicleCapacity = TextEditingController();
  final _notes = TextEditingController();

  final Map<String, Map<String, dynamic>> _documents = {};
  final Map<String, TextEditingController> _documentNumbers = {};
  final Map<String, DateTime?> _documentDates = {};

  String? _selectedVehicleType;

  static const List<String> _vehicleTypes = [
    'Sedan',
    'Hatchback',
    'SUV',
    'Van',
    'Pet Transport Van',
    'Large Animal Transport',
  ];

  static const List<_DocSpec> _requiredDocs = [
    _DocSpec(
      key: 'taxPlate',
      label: 'Vergi levhası / tax plate',
      required: true,
    ),
    _DocSpec(
      key: 'businessRegistration',
      label: 'Faaliyet belgesi / company registration',
      required: true,
    ),
    _DocSpec(
      key: 'vehicleRegistration',
      label: 'Araç ruhsatı / vehicle registration',
      required: true,
      requiredDocumentNumber: true,
      dateField: 'vehicleRegistrationIssueDate',
      dateLabel: 'Vehicle registration issue date',
      pastAllowed: true,
    ),
    _DocSpec(
      key: 'driverLicense',
      label: 'Sürücü belgesi / driver license',
      required: true,
      requiredDocumentNumber: true,
      dateField: 'driverLicenseExpiryDate',
      dateLabel: 'Driver license expiry date',
    ),
    _DocSpec(
      key: 'trafficInsurance',
      label: 'Zorunlu trafik sigortası / mandatory traffic insurance',
      required: true,
      requiredDocumentNumber: true,
      dateField: 'trafficInsuranceExpiryDate',
      dateLabel: 'Traffic insurance expiry date',
    ),
  ];

  static const List<_DocSpec> _optionalDocs = [
    _DocSpec(
      key: 'srcCertificate',
      label: 'SRC certificate, if applicable',
      dateField: 'srcCertificateExpiryDate',
      dateLabel: 'SRC certificate expiry date',
    ),
    _DocSpec(
      key: 'psychotechnicalReport',
      label: 'Psikoteknik raporu, if applicable',
      dateField: 'psychotechnicalReportExpiryDate',
      dateLabel: 'Psychotechnical report expiry date',
    ),
    _DocSpec(
      key: 'criminalRecord',
      label: 'Adli sicil kaydı / criminal record, optional',
    ),
    _DocSpec(
      key: 'kaskoInsurance',
      label: 'Kasko insurance, optional',
      dateField: 'kaskoInsuranceExpiryDate',
      dateLabel: 'Kasko insurance expiry date',
    ),
  ];

  List<_DocSpec> get _allDocs => [..._requiredDocs, ..._optionalDocs];

  @override
  void initState() {
    super.initState();
    for (final spec in _allDocs) {
      _documentNumbers[spec.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _driverName.dispose();
    _driverPhone.dispose();
    _vehiclePlate.dispose();

    _vehicleCapacity.dispose();
    _notes.dispose();
    for (final controller in _documentNumbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _uploadFile(File file, String field) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final extension = file.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
    final ref = FirebaseStorage.instance.ref().child(
      'business_sector_docs/${user.uid}/pet_taxi/$field/${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await ref.putFile(file, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    return {
      'url': url,
      'storagePath': ref.fullPath,
      'uploadedAt': DateTime.now().toIso8601String(),
      'uploadedBy': user.uid,
      'status': 'pending_review',
      'verified': false,
      'rejectedReason': null,
      'contentType': contentType,
      'fileName': file.path.split(Platform.pathSeparator).last,
    };
  }

  Future<void> _pickDocument(_DocSpec spec) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _loading = true);
    try {
      final metadata = await _uploadFile(File(path), spec.key);
      if (!mounted) return;
      setState(() => _documents[spec.key] = metadata);
    } catch (e) {
      debugPrint('PetTaxiRegistration upload error: ${e.toString()}');
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(_DocSpec spec) async {
    final now = DateTime.now();
    final current = _documentDates[spec.key];
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: spec.pastAllowed ? DateTime(now.year - 30) : now,
      lastDate: DateTime(now.year + 20),
    );
    if (date == null) return;
    setState(() => _documentDates[spec.key] = date);
  }

  Future<void> _openDocument(_DocSpec spec) async {
    final url = _documents[spec.key]?['url']?.toString();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _snack('Could not open document');
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final plate = _normalizeTurkishPlate(_vehiclePlate.text);
    if (plate == null) {
      _snack('Enter a valid Turkish vehicle plate');
      return;
    }

    final missingDocs = _requiredDocs
        .where((spec) => !_documents.containsKey(spec.key))
        .map((spec) => spec.label)
        .toList();
    if (missingDocs.isNotEmpty) {
      _snack('Upload all required legal and vehicle documents');
      return;
    }

    final dateError = _validateDocumentDates();
    if (dateError != null) {
      _snack(dateError);
      return;
    }

    final numberError = _validateDocumentNumbers();
    if (numberError != null) {
      _snack(numberError);
      return;
    }

    if (!_petSafetyConfirmed ||
        !_hygieneConfirmed ||
        !_driverLicenseValidConfirmed ||
        !_vehicleRegistrationConfirmed ||
        !_trafficInsuranceConfirmed ||
        !_taxResponsibilityConfirmed ||
        !_transportRulesConfirmed) {
      _snack('Confirm all required compliance statements');
      return;
    }

    final documents = <String, dynamic>{};
    for (final spec in _allDocs) {
      final uploaded = _documents[spec.key];
      if (uploaded == null) continue;
      documents[spec.key] = {
        ...uploaded,
        'documentNumber':
            _documentNumbers[spec.key]?.text.trim().isEmpty == true
            ? null
            : _documentNumbers[spec.key]?.text.trim(),
        if (spec.dateField != null)
          spec.dateField!: _documentDates[spec.key]?.toIso8601String(),
        'expiryDate': spec.dateField?.contains('Expiry') == true
            ? _documentDates[spec.key]?.toIso8601String()
            : null,
      };
    }

    final petTaxiData = {
      'displayName': widget.baseDraft.profile.displayName,
      'description': widget.baseDraft.profile.description,
      'driver': {
        'fullName': _driverName.text.trim(),
        'phoneNumber': _normalizePhone(_driverPhone.text),
      },
      'vehicle': {
        'plateNumber': plate,
        'vehicleType': _selectedVehicleType,
        'capacity': int.parse(_vehicleCapacity.text.trim()),
      },
      'documents': {
        ...documents,
        'requiredDocumentKeys': _requiredDocs.map((doc) => doc.key).toList(),
        'optionalDocumentKeys': _optionalDocs.map((doc) => doc.key).toList(),
      },
      'compliance': {
        'petSafetyEquipmentConfirmed': _petSafetyConfirmed,
        'hygieneSanitationConfirmed': _hygieneConfirmed,
        'driverLicenseValidConfirmed': _driverLicenseValidConfirmed,
        'vehicleRegistrationConfirmed': _vehicleRegistrationConfirmed,
        'trafficInsuranceConfirmed': _trafficInsuranceConfirmed,
        'taxResponsibilityConfirmed': _taxResponsibilityConfirmed,
        'transportRulesConfirmed': _transportRulesConfirmed,
        'manualReviewRequired': true,
        'status': 'pending_review',
        'reviewedBy': null,
        'reviewedAt': null,
        'rejectionReason': null,
        'approvedAt': null,
        'note': _notes.text.trim(),
      },
      'isActive': false,
      'published': false,
    };

    final updatedDraft = widget.baseDraft.copyWith(
      sectorData: {...widget.baseDraft.sectorData, 'pet_taxi': petTaxiData},
    );

    if (!mounted) return;
    Navigator.of(context).pop(updatedDraft);
  }

  String? _validateDocumentDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final spec in _allDocs) {
      final uploaded = _documents.containsKey(spec.key);

      if (!uploaded) {
        if (spec.required) {
          return '${spec.label} is required';
        }
        continue;
      }
      if (spec.dateField == null) continue;

      final date = _documentDates[spec.key];
      if (date == null) return '${spec.dateLabel} is required';

      final normalized = DateTime(date.year, date.month, date.day);
      if (!spec.pastAllowed && normalized.isBefore(today)) {
        return '${spec.dateLabel} cannot be in the past';
      }
    }
    return null;
  }

  String? _validateDocumentNumbers() {
    for (final spec in _allDocs) {
      if (!spec.requiredDocumentNumber) continue;
      if (!_documents.containsKey(spec.key)) continue;

      final number = _documentNumbers[spec.key]?.text.trim() ?? '';
      if (number.isEmpty) {
        return '${spec.label} document number is required';
      }
    }
    return null;
  }

  String? _normalizeTurkishPlate(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final match = RegExp(
      r'^([0-9]{2})([A-Z]{1,3})([0-9]{2,4})$',
    ).firstMatch(compact);
    if (match == null) return null;
    final city = int.tryParse(match.group(1)!);
    if (city == null || city < 1 || city > 81) return null;
    return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[\s()-]'), '');
  }

  String? _phoneValidator(String? value) {
    final phone = _normalizePhone(value ?? '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _capacityValidator(String? value) {
    final capacity = int.tryParse((value ?? '').trim());

    if (capacity == null) {
      return 'Enter valid capacity';
    }

    if (capacity < 1) {
      return 'Capacity must be at least 1';
    }

    if (capacity > 15) {
      return 'Capacity is unrealistically high';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Taxi Details')),
      
      body: GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () {
    FocusScope.of(context).unfocus();
  },
  child: Form(
    key: _formKey,
    child: ListView(
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      children: [
         
            _basicInfoCard(),
            const SizedBox(height: 12),
            _sectionTile(
              title: 'Required Documents',
              subtitle: 'Legal documents required for manual admin review',
              initiallyExpanded: true,
              children: _requiredDocs.map(_docTile).toList(),
            ),
            const SizedBox(height: 12),
            _sectionTile(
              title: 'Optional / Conditional Documents',
              subtitle: 'Upload these if they apply to your service',
              children: _optionalDocs.map(_docTile).toList(),
            ),
            const SizedBox(height: 12),
            _sectionTile(
              title: 'Compliance & Legal Confirmations',
              subtitle: 'Required confirmations before submitting',
              children: [
                const Text(
                  'Your Pet Taxi application will not be published until documents are manually reviewed and approved.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9E1B4F),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Transportation laws may vary by city/country. Businesses are responsible for complying with local transportation, insurance, and tax regulations.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Legal documents are stored for business owner and admin review only. They are not shown to public users.',
                ),
                const SizedBox(height: 12),
                _check(
                  value: _petSafetyConfirmed,
                  onChanged: (value) =>
                      setState(() => _petSafetyConfirmed = value),
                  title: 'Pet safety equipment is available in the vehicle.',
                ),
                _check(
                  value: _hygieneConfirmed,
                  onChanged: (value) =>
                      setState(() => _hygieneConfirmed = value),
                  title: 'Hygiene and sanitation requirements are confirmed.',
                ),
                _check(
                  value: _driverLicenseValidConfirmed,
                  onChanged: (value) =>
                      setState(() => _driverLicenseValidConfirmed = value),
                  title: 'I confirm driver license is valid.',
                ),
                _check(
                  value: _vehicleRegistrationConfirmed,
                  onChanged: (value) =>
                      setState(() => _vehicleRegistrationConfirmed = value),
                  title:
                      'I confirm vehicle registration belongs to the service vehicle.',
                ),
                _check(
                  value: _trafficInsuranceConfirmed,
                  onChanged: (value) =>
                      setState(() => _trafficInsuranceConfirmed = value),
                  title: 'I confirm traffic insurance is active.',
                ),
                _check(
                  value: _taxResponsibilityConfirmed,
                  onChanged: (value) =>
                      setState(() => _taxResponsibilityConfirmed = value),
                  title:
                      'I confirm tax obligations and invoice/receipt responsibilities belong to my business.',
                ),
                _check(
                  value: _transportRulesConfirmed,
                  onChanged: (value) =>
                      setState(() => _transportRulesConfirmed = value),
                  title:
                      'I confirm I comply with city/country transportation rules.',
                ),
                _field(
                  _notes,
                  'Compliance notes for admin review',
                  required: false,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Pet Taxi Details'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (required
                ? (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null
                : null),
      ),
    );
  }

  Widget _basicInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver & Vehicle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _field(_driverName, 'Driver full name'),
            _field(
              _driverPhone,
              'Driver phone number',
              keyboardType: TextInputType.phone,
              validator: _phoneValidator,
            ),
            _field(
              _vehiclePlate,
              'Vehicle plate number',
              onChanged: (value) {
                final plate = _normalizeTurkishPlate(value);
                if (plate != null && plate != value) {
                  _vehiclePlate.value = TextEditingValue(
                    text: plate,
                    selection: TextSelection.collapsed(offset: plate.length),
                  );
                }
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              items: _vehicleTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedVehicleType = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select vehicle type';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              _vehicleCapacity,
              'Vehicle capacity',
              keyboardType: TextInputType.number,
              validator: _capacityValidator,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        children: children,
      ),
    );
  }

  Widget _docTile(_DocSpec spec) {
    final uploaded = _documents.containsKey(spec.key);
    final fileName = _documents[spec.key]?['fileName']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(uploaded ? Icons.check_circle : Icons.upload_file),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        spec.required ? 'Required' : 'Optional / if applicable',
                      ),
                      if (fileName != null) Text(fileName),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _loading ? null : () => _pickDocument(spec),
                    child: Text(uploaded ? 'Replace file' : 'Upload PDF/Image'),
                  ),
                ),
                if (uploaded)
                  Expanded(
                    child: TextButton(
                      onPressed: () => _openDocument(spec),
                      child: const Text('Preview'),
                    ),
                  ),
              ],
            ),
            if (uploaded || spec.required) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _documentNumbers[spec.key],
                decoration: InputDecoration(
                  labelText: spec.requiredDocumentNumber
                      ? 'Document number'
                      : 'Document number (optional)',
                ),
                validator: (value) {
                  if (!spec.requiredDocumentNumber) return null;
                  if (!_documents.containsKey(spec.key)) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Document number is required';
                  }
                  return null;
                },
              ),
              if (spec.dateField != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _pickDate(spec),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _documentDates[spec.key] == null
                          ? spec.dateLabel!
                          : '${spec.dateLabel}: ${_dateText(_documentDates[spec.key]!)}',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      title: Text(title),
    );
  }

  String _dateText(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DocSpec {
  final String key;
  final String label;
  final bool required;
  final bool requiredDocumentNumber;
  final String? dateField;
  final String? dateLabel;
  final bool pastAllowed;

  const _DocSpec({
    required this.key,
    required this.label,
    this.required = false,
    this.requiredDocumentNumber = false,
    this.dateField,
    this.dateLabel,
    this.pastAllowed = false,
  });
}
