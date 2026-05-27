import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/business_draft.dart';
import '../../../theme/app_theme.dart';

class VetDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  // ✅ very important: these were previously sent from BusinessRegisterPage
  final double? lat;
  final double? lng;
  final String? countryCode;
  final String? admin1Id;
  final String? admin2Id;

  const VetDetailsPage({
    super.key,
    required this.baseDraft,
    required this.lat,
    required this.lng,
    required this.countryCode,
    required this.admin1Id,
    required this.admin2Id,
  });

  @override
  State<VetDetailsPage> createState() => _VetDetailsPageState();
}

class _VetDetailsPageState extends State<VetDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  final _scrollController = ScrollController();
  // =========================================================
  // SECTION 1 — Temel Bilgiler / Basic Information
  // Only fields that are NOT already captured in baseDraft
  // =========================================================
  final TextEditingController _clinicName = TextEditingController();
  final TextEditingController _responsibleName = TextEditingController();
  final TextEditingController _role = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _landline = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _fullAddress = TextEditingController();
  final TextEditingController _locationText = TextEditingController();
  final TextEditingController _cityDistrict = TextEditingController();

  // =========================================================
  // SECTION 2 — Ruhsat & Doğrulama / License & Verification
  // =========================================================
  final TextEditingController _licenseNumber = TextEditingController();
  final TextEditingController _issuingAuthority = TextEditingController();
  DateTime? _licenseExpiryDate;
  String? _licenseDocumentUrl;
  final TextEditingController _taxOrBusinessInfo = TextEditingController();
  final TextEditingController _authorizedContractPerson =
      TextEditingController();

  // =========================================================
  // SECTION 4 — Çalışma Saatleri / Working Hours
  // =========================================================
  final List<String> _selectedWorkingDays = [];
  final TextEditingController _workingHours = TextEditingController();
  String _weekendOpen = 'yes';
  String _emergencyService = '24_hours';

  // =========================================================
  // SECTION 5 — Operasyonel Bilgiler / Operational Details
  // =========================================================
  final List<String> _acceptedAnimalTypes = [];
  String _offersHomeService = 'no';
  String _offersOnlineConsultation = 'no';
  final TextEditingController _dailyCapacity = TextEditingController();

  // =========================================================
  // SECTION 6 — Profil İçeriği / Profile Content
  // =========================================================
  String? _clinicLogoUrl;
  final List<String> _clinicPhotoUrls = [];
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _specialties = TextEditingController();
  final TextEditingController _yearEstablished = TextEditingController();
  final TextEditingController _instagram = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _website = TextEditingController();

  // =========================================================
  // SECTION 7 — İşbirliği & Ödeme / Partnership & Payment
  // =========================================================
  String _partnershipModel = 'monthly_subscription';
  final TextEditingController _iban = TextEditingController();
  final TextEditingController _billingInformation = TextEditingController();
  final TextEditingController _financialContactPerson = TextEditingController();

  // =========================================================
  // SECTION 8 — Pazarlama & Kampanyalar / Marketing & Promotions
  // =========================================================
  String _offerDiscountToUsers = 'no';
  final TextEditingController _promotionDetails = TextEditingController();
  String _featuredVet = 'no';

  // =========================================================
  // SECTION 9 — Onaylar / Agreements
  // =========================================================
  bool _confirmAccuracy = false;
  bool _agreeDisplayInfo = false;
  bool _agreeUserReviews = false;
  bool _acceptPartnershipTerms = false;

  String? _nameValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';

    if (text.length < 3) return 'Too short';

    final regex = RegExp(r'^[a-zA-Z\s]+$');
    if (!regex.hasMatch(text)) return 'Only letters allowed';

    return null;
  }

  String? _yearValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;

    final year = int.tryParse(text);
    if (year == null) return 'Invalid year';

    final currentYear = DateTime.now().year;

    if (year < 1950) return 'Too old';
    if (year > currentYear) return 'Future year not allowed';

    return null;
  }

  String? _ibanValidator(String? v) {
    final text = (v ?? '').replaceAll(' ', '');

    if (text.isEmpty) return null;

    final regex = RegExp(r'^TR\d{24}$');
    if (!regex.hasMatch(text)) {
      return 'Invalid IBAN (TR + 24 digits)';
    }

    return null;
  }

  String? _dailyCapacityValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;

    final value = int.tryParse(text);
    if (value == null) return 'Enter a number';

    if (value < 1) return 'Must be at least 1';
    if (value > 50) return 'Too high (max 50 per day)';

    return null;
  }

  String? _workingHoursValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';

    final regex = RegExp(r'^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$');
    if (!regex.hasMatch(text)) {
      return 'Format must be like 09:00 - 18:00';
    }

    return null;
  }

  String? _phoneValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';

    final regex = RegExp(r'^[0-9]{10,15}$');
    if (!regex.hasMatch(text)) return 'Invalid phone number';

    return null;
  }

  String? _licenseValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';
    if (text.length < 5) return 'Must be at least 5 characters';

    final regex = RegExp(r'^[a-zA-Z0-9\-\/]+$');
    if (!regex.hasMatch(text)) {
      return 'Only letters, numbers, dash, and slash are allowed';
    }

    return null;
  }

  static const List<String> _allWorkingDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _allAnimalTypes = ['Dog', 'Cat', 'Bird', 'Exotic'];

  @override
  void initState() {
    super.initState();
    _prefillFromBaseDraft();
  }

  void _prefillFromBaseDraft() {
    final contact = widget.baseDraft.contact;
    final profile = widget.baseDraft.profile;
    final legal = widget.baseDraft.legal;

    _mobile.text = contact.phone;
    _email.text = contact.email;
    _whatsapp.text = contact.whatsapp;
    _website.text = contact.website;
    _fullAddress.text = contact.addressLine;
    _cityDistrict.text = [
      contact.city,
      contact.district,
    ].where((e) => e.trim().isNotEmpty).join(' / ');

    _clinicName.text = profile.displayName;
    _taxOrBusinessInfo.text = [
      if ((legal.taxNumber).trim().isNotEmpty) 'Tax: ${legal.taxNumber}',
      if ((legal.mersisNumber).trim().isNotEmpty)
        'MERSIS: ${legal.mersisNumber}',
    ].join(' | ');

    if (widget.lat != null && widget.lng != null) {
      _locationText.text = '${widget.lat}, ${widget.lng}';
    }
  }

  @override
  void dispose() {
    _clinicName.dispose();
    _responsibleName.dispose();
    _role.dispose();
    _mobile.dispose();
    _landline.dispose();
    _email.dispose();
    _fullAddress.dispose();
    _locationText.dispose();
    _cityDistrict.dispose();

    _licenseNumber.dispose();
    _issuingAuthority.dispose();
    _taxOrBusinessInfo.dispose();
    _authorizedContractPerson.dispose();

    _workingHours.dispose();

    _dailyCapacity.dispose();

    _bio.dispose();
    _specialties.dispose();
    _yearEstablished.dispose();
    _instagram.dispose();
    _whatsapp.dispose();
    _website.dispose();

    _iban.dispose();
    _billingInformation.dispose();
    _financialContactPerson.dispose();

    _promotionDetails.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<String> _uploadFile(File file, String folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final uid = user.uid;

    final ref = FirebaseStorage.instance.ref().child(
      'business_sector_docs/$uid/$folder/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _pickLicenseDocument() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), 'vet_license');
      if (!mounted) return;
      setState(() => _licenseDocumentUrl = url);
      _snack('License document uploaded');
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickClinicLogo() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), 'vet_logo');
      if (!mounted) return;
      setState(() => _clinicLogoUrl = url);
      _snack('Clinic logo uploaded');
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickClinicPhoto() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), 'vet_photos');
      if (!mounted) return;
      setState(() => _clinicPhotoUrls.add(url));
      _snack('Clinic photo uploaded');
    } catch (e) {
      _snack('Failed to upload clinic photo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLicenseExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );

    if (picked != null) {
      setState(() => _licenseExpiryDate = picked);
    }
  }

  void _toggleSelection(List<String> source, String value) {
    setState(() {
      if (source.contains(value)) {
        source.remove(value);
      } else {
        source.add(value);
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _optionalEmailValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(text)) return 'Invalid email';
    return null;
  }

  String? _optionalNumberValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    if (int.tryParse(text) == null) return 'Enter a valid number';
    return null;
  }

  Map<String, dynamic> _buildVetData() {
    return {
      // SECTION 1
      'clinicName': _clinicName.text.trim(),
      'responsiblePersonName': _responsibleName.text.trim(),
      'responsiblePersonRole': _role.text.trim(),
      'mobilePhone': _mobile.text.trim(),
      'landlinePhone': _landline.text.trim(),
      'email': _email.text.trim(),
      'fullAddress': _fullAddress.text.trim(),
      'location': _locationText.text.trim(),
      'cityDistrict': _cityDistrict.text.trim(),

      // SECTION 2
      'licenseVerification': {
        'licenseNumber': _licenseNumber.text.trim(),
        'issuingAuthority': _issuingAuthority.text.trim(),
        'licenseExpiryDate': _licenseExpiryDate?.toIso8601String(),
        'licenseDocumentUrl': _licenseDocumentUrl,
        'taxOrBusinessInfo': _taxOrBusinessInfo.text.trim(),
        'authorizedContractPerson': _authorizedContractPerson.text.trim(),
      },

      // SECTION 4
      'workingHours': {
        'workingDays': _selectedWorkingDays,
        'workingHours': _workingHours.text.trim(),
        'weekendOpen': _weekendOpen,
        'emergencyService': _emergencyService,
      },

      // SECTION 5
      'operationalDetails': {
        'acceptedAnimalTypes': _acceptedAnimalTypes,
        'offersHomeService': _offersHomeService,
        'offersOnlineConsultation': _offersOnlineConsultation,
        'dailyCapacity': int.tryParse(_dailyCapacity.text.trim()),
      },

      // SECTION 6
      'profileContent': {
        'clinicLogoUrl': _clinicLogoUrl,
        'clinicPhotoUrls': _clinicPhotoUrls,
        'bio': _bio.text.trim(),
        'specialties': _specialties.text.trim(),
        'yearEstablished': int.tryParse(_yearEstablished.text.trim()),
        'socialMedia': {
          'instagram': _instagram.text.trim(),
          'whatsapp': _whatsapp.text.trim(),
          'website': _website.text.trim(),
        },
      },

      // SECTION 7
      'partnershipPayment': {
        'partnershipModel': _partnershipModel,
        'iban': _iban.text.trim(),
        'billingInformation': _billingInformation.text.trim(),
        'financialContactPerson': _financialContactPerson.text.trim(),
      },

      // SECTION 8
      'marketingPromotions': {
        'offerDiscountToUsers': _offerDiscountToUsers,
        'promotionDetails': _promotionDetails.text.trim(),
        'featuredVet': _featuredVet,
      },

      // SECTION 9
      'agreements': {
        'confirmAccuracy': _confirmAccuracy,
        'agreeDisplayInfo': _agreeDisplayInfo,
        'agreeUserReviews': _agreeUserReviews,
        'acceptPartnershipTerms': _acceptPartnershipTerms,
      },
    };
  }

  Future<void> _submit() async {
    if (_loading) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _snack('Please fix highlighted fields');

      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });

      return;
    }

    if (_selectedWorkingDays.isEmpty) {
      _snack('Please select working days');
      return;
    }

    if (_acceptedAnimalTypes.isEmpty) {
      _snack('Please select accepted animal types');
      return;
    }

    if (_licenseExpiryDate == null) {
      _snack('License expiry date is required');
      return;
    }

    if (_licenseDocumentUrl == null) {
      _snack('Please upload license document');
      return;
    }

    if (!_confirmAccuracy ||
        !_agreeDisplayInfo ||
        !_agreeUserReviews ||
        !_acceptPartnershipTerms) {
      _snack('You must accept all agreements');
      return;
    }

    setState(() => _loading = true);

    try {
      final updatedDraft = widget.baseDraft.copyWith(
        sectorData: {
          ...widget.baseDraft.sectorData,
          'veterinary': _buildVetData(),
        },
      );

      if (!mounted) return;

      // 🔥 فقط data برگردون
      Navigator.pop(context, updatedDraft);
    } catch (e) {
      _snack('Unexpected error occurred');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(title, style: AppTheme.h2()),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    String? hintText,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          helperText: helperText,
          errorStyle: const TextStyle(color: Colors.red),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade200 : Colors.grey.shade100,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _choiceChipList({
    required List<String> items,
    required List<String> selectedValues,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = selectedValues.contains(item);
        return FilterChip(
          label: Text(item),
          selected: selected,
          onSelected: (_) => _toggleSelection(selectedValues, item),
          selectedColor: AppTheme.accent.withOpacity(0.18),
          checkmarkColor: AppTheme.accent,
          side: BorderSide(
            color: selected ? AppTheme.accent : Colors.grey.shade300,
          ),
        );
      }).toList(),
    );
  }

  Widget _radioGroup<T>({
    required String title,
    required T value,
    required List<MapEntry<T, String>> options,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...options.map(
            (option) => RadioListTile<T>(
              value: option.key,
              groupValue: value,
              contentPadding: EdgeInsets.zero,
              title: Text(option.value),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadTile({
    required String title,
    required String? url,
    required VoidCallback onTap,
    bool multiple = false,
    int itemCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              multiple
                  ? '$title ($itemCount uploaded)'
                  : (url == null ? title : '$title ✓'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(url == null && !multiple ? 'Upload' : 'Change'),
          ),
        ],
      ),
    );
  }

  Widget _summaryInheritedInfo() {
    return _card([
      Text(
        'Inherited from base registration',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 10),
      _field(controller: _mobile, label: 'Mobile Phone', readOnly: true),
      _field(controller: _email, label: 'Email Address', readOnly: true),
      _field(controller: _fullAddress, label: 'Full Address', readOnly: true),
      _field(
        controller: _locationText,
        label: 'Location (coordinates)',
        readOnly: true,
      ),
      _field(
        controller: _cityDistrict,
        label: 'City / District',
        readOnly: true,
      ),
      _field(
        controller: _taxOrBusinessInfo,
        label: 'Tax / Business Info',
        readOnly: true,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Veterinary Details'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryInheritedInfo(),

                      // SECTION 1
                      _card([
                        _sectionHeader('SECTION 1 — Temel Bilgiler'),
                        _field(
                          controller: _clinicName,
                          label: '1. Clinic / Veterinary Center Name',
                          validator: _nameValidator,
                        ),
                        _field(
                          controller: _responsibleName,
                          label: '2. Full Name of Responsible Person',
                          validator: _nameValidator,
                        ),
                        _field(
                          controller: _role,
                          label: '3. Role (Veterinarian, Manager, etc.)',
                          validator: _nameValidator,
                        ),
                        _field(
                          controller: _landline,
                          label: '5. Landline Phone (Optional)',
                        ),
                      ]),

                      // SECTION 2
                      _card([
                        _sectionHeader('SECTION 2 — License & Verification'),
                        _field(
                          controller: _licenseNumber,
                          label: '10. Veterinary License Number',
                          hintText: 'e.g. TR-45821',
                          helperText:
                              'Enter the official license number issued by the veterinary authority. Minimum 5 characters.',
                          validator: _licenseValidator,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            'This number will be reviewed during verification.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        _field(
                          controller: _issuingAuthority,
                          label: '11. Issuing Authority',
                          validator: _requiredValidator,
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _pickLicenseExpiryDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '12. License Expiry Date',
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              child: Text(_formatDate(_licenseExpiryDate)),
                            ),
                          ),
                        ),
                        _uploadTile(
                          title: '13. Upload License Document',
                          url: _licenseDocumentUrl,
                          onTap: _loading ? () {} : _pickLicenseDocument,
                        ),
                        _field(
                          controller: _authorizedContractPerson,
                          label: '15. Authorized Person for Contract',
                          validator: _requiredValidator,
                        ),
                      ]),

                      // SECTION 4
                      _card([
                        _sectionHeader('SECTION 4 — Working Hours'),
                        Text(
                          '20. Working Days',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _choiceChipList(
                          items: _allWorkingDays,
                          selectedValues: _selectedWorkingDays,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _workingHours,
                          label: '21. Working Hours',
                          validator: _workingHoursValidator,
                          hintText: '09:00 - 18:00',
                        ),
                        _radioGroup<String>(
                          title: '22. Open on Weekends?',
                          value: _weekendOpen,
                          options: const [
                            MapEntry('yes', 'Yes'),
                            MapEntry('no', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _weekendOpen = v);
                            }
                          },
                        ),
                        _radioGroup<String>(
                          title: '23. Emergency Service Available?',
                          value: _emergencyService,
                          options: const [
                            MapEntry('24_hours', '24 Hours'),
                            MapEntry('limited_hours', 'Limited Hours'),
                            MapEntry('none', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _emergencyService = v);
                            }
                          },
                        ),
                      ]),

                      // SECTION 5
                      _card([
                        _sectionHeader('SECTION 5 — Operational Details'),
                        Text(
                          '24. Accepted Animal Types',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _choiceChipList(
                          items: _allAnimalTypes,
                          selectedValues: _acceptedAnimalTypes,
                        ),
                        const SizedBox(height: 14),
                        _radioGroup<String>(
                          title: '25. Do you offer home service?',
                          value: _offersHomeService,
                          options: const [
                            MapEntry('yes', 'Yes'),
                            MapEntry('no', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _offersHomeService = v);
                            }
                          },
                        ),
                        _radioGroup<String>(
                          title: '26. Do you offer online consultation?',
                          value: _offersOnlineConsultation,
                          options: const [
                            MapEntry('yes', 'Yes'),
                            MapEntry('no', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _offersOnlineConsultation = v);
                            }
                          },
                        ),
                        _field(
                          controller: _dailyCapacity,
                          label: '27. Daily Capacity',
                          keyboardType: TextInputType.number,
                          validator: _dailyCapacityValidator,
                          hintText: 'e.g. 10-30 patients per day',
                          helperText:
                              'Typical clinics handle 10–30 patients daily',
                        ),
                      ]),

                      // SECTION 6
                      _card([
                        _sectionHeader('SECTION 6 — Profile Content'),
                        _uploadTile(
                          title: '28. Upload Clinic Logo',
                          url: _clinicLogoUrl,
                          onTap: _loading ? () {} : _pickClinicLogo,
                        ),
                        _uploadTile(
                          title: '29. Upload Clinic Photos',
                          url: null,
                          multiple: true,
                          itemCount: _clinicPhotoUrls.length,
                          onTap: _loading ? () {} : _pickClinicPhoto,
                        ),
                        _field(
                          controller: _bio,
                          label: '30. Short Description (Bio)',
                          validator: _requiredValidator,
                          maxLines: 4,
                        ),
                        _field(
                          controller: _specialties,
                          label: '31. Specialties',
                          validator: _requiredValidator,
                        ),
                        _field(
                          controller: _yearEstablished,
                          label: '32. Year Established',
                          keyboardType: TextInputType.number,
                          validator: _yearValidator,
                          hintText: 'e.g. 2015',
                        ),
                        _field(controller: _instagram, label: '33. Instagram'),
                        _field(controller: _whatsapp, label: '33. WhatsApp'),
                        _field(controller: _website, label: '33. Website'),
                      ]),

                      // SECTION 7
                      _card([
                        _sectionHeader('SECTION 7 — Partnership & Payment'),
                        _radioGroup<String>(
                          title: '34. Preferred Partnership Model',
                          value: _partnershipModel,
                          options: const [
                            MapEntry(
                              'monthly_subscription',
                              'Monthly Subscription',
                            ),
                            MapEntry('commission', 'Commission per booking'),
                            MapEntry('pay_per_lead', 'Pay per lead'),
                            MapEntry('advertising', 'Advertising'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _partnershipModel = v);
                            }
                          },
                        ),
                        _field(
                          controller: _iban,
                          label: '35. IBAN / Payment Details',
                          validator: _ibanValidator,
                          hintText: 'TRXXXXXXXXXXXXXXXXXXXXXXXX',
                        ),
                        _field(
                          controller: _billingInformation,
                          label: '36. Billing Information',
                        ),
                        _field(
                          controller: _financialContactPerson,
                          label: '37. Financial Contact Person',
                        ),
                      ]),

                      // SECTION 8
                      _card([
                        _sectionHeader('SECTION 8 — Marketing & Promotions'),
                        _radioGroup<String>(
                          title: '38. Offer discounts to PetSopu users?',
                          value: _offerDiscountToUsers,
                          options: const [
                            MapEntry('yes', 'Yes'),
                            MapEntry('no', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _offerDiscountToUsers = v);
                            }
                          },
                        ),
                        if (_offerDiscountToUsers == 'yes')
                          _field(
                            controller: _promotionDetails,
                            label: '39. Promotion Details',
                            maxLines: 3,
                            hintText: 'e.g. 15% discount on vaccinations',
                            helperText: 'Describe your offer clearly',
                          ),
                        _radioGroup<String>(
                          title: '40. Interested in being a Featured Vet?',
                          value: _featuredVet,
                          options: const [
                            MapEntry('yes', 'Yes'),
                            MapEntry('no', 'No'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _featuredVet = v);
                            }
                          },
                        ),
                      ]),

                      // SECTION 9
                      _card([
                        _sectionHeader('SECTION 9 — Agreements'),
                        CheckboxListTile(
                          value: _confirmAccuracy,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '41. I confirm that the information provided is accurate',
                          ),
                          onChanged: (v) =>
                              setState(() => _confirmAccuracy = v ?? false),
                        ),
                        CheckboxListTile(
                          value: _agreeDisplayInfo,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '42. I agree to display my information in the app',
                          ),
                          onChanged: (v) =>
                              setState(() => _agreeDisplayInfo = v ?? false),
                        ),
                        CheckboxListTile(
                          value: _agreeUserReviews,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '43. I agree to user reviews being displayed',
                          ),
                          onChanged: (v) =>
                              setState(() => _agreeUserReviews = v ?? false),
                        ),
                        CheckboxListTile(
                          value: _acceptPartnershipTerms,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '44. I accept PetSopu partnership terms',
                          ),
                          onChanged: (v) => setState(
                            () => _acceptPartnershipTerms = v ?? false,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Veterinary Details',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
