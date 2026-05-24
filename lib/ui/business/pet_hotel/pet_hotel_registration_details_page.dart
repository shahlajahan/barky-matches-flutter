import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/business_draft.dart';

class PetHotelRegistrationDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  const PetHotelRegistrationDetailsPage({super.key, required this.baseDraft});

  @override
  State<PetHotelRegistrationDetailsPage> createState() =>
      _PetHotelRegistrationDetailsPageState();
}

class _PetHotelRegistrationDetailsPageState
    extends State<PetHotelRegistrationDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  final TextEditingController _hotelName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _instagram = TextEditingController();
  final TextEditingController _workingHours = TextEditingController();
  final TextEditingController _capacity = TextEditingController(text: '25');

  final List<String> _allServices = const [
    'Standard Room',
    'VIP Room',
    'Cat Room',
    'Daily Care',
    'Overnight Stay',
    'Long Stay',
    'Camera Access',
    'Pickup Service',
  ];

  final List<String> _amenityOptions = const [
    '24/7 Staff',
    'Camera Access',
    'Outdoor Play Area',
    'Vet On Call',
    'Pickup Service',
    'Cat Rooms',
    'Medication Support',
  ];

  final List<String> _days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _selectedServices = [];
  final List<String> _selectedAmenities = [];
  final List<String> _selectedDays = [];

  String? _logoUrl;
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    final contact = widget.baseDraft.contact;
    final profile = widget.baseDraft.profile;
    _hotelName.text = profile.displayName;
    _phone.text = contact.phone;
    _whatsapp.text = contact.whatsapp;
  }

  @override
  void dispose() {
    _hotelName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _workingHours.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _toggle(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  Future<String> _uploadFile(File file, String folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final ref = FirebaseStorage.instance.ref().child(
      'business_sector_docs/${user.uid}/pet_hotel/$folder/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _pickLogo() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), 'logo');
      if (!mounted) return;
      setState(() => _logoUrl = url);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), 'photos');
      if (!mounted) return;
      setState(() => _photos.add(url));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildData() {
    final weekendOpen =
        _selectedDays.contains('Saturday') || _selectedDays.contains('Sunday');
    final maxCapacity = int.tryParse(_capacity.text.trim()) ?? 25;

    return {
      'displayName': _hotelName.text.trim(),
      'description': widget.baseDraft.profile.description,
      'logo': _logoUrl,
      'coverImage': _photos.isNotEmpty ? _photos.first : null,
      'specialties': _selectedServices,
      'amenities': _selectedAmenities,
      'maxCapacity': maxCapacity,
      'capacity': {'maxCapacity': maxCapacity},
      'contact': {
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'instagram': _instagram.text.trim(),
      },
      'services': {'offeredServices': _selectedServices},
      'workingHours': {
        'workingDays': _selectedDays,
        'workingHours': _workingHours.text.trim(),
        'weekendOpen': weekendOpen,
      },
      'operationalDetails': {
        'pickupService': _selectedAmenities.contains('Pickup Service'),
        'cameraAccess': _selectedAmenities.contains('Camera Access'),
        'vetOnCall': _selectedAmenities.contains('Vet On Call'),
      },
      'profileContent': {
        'clinicLogoUrl': _logoUrl,
        'clinicPhotoUrls': _photos,
        'socialMedia': {
          'whatsapp': _whatsapp.text.trim(),
          'instagram': _instagram.text.trim(),
        },
      },
    };
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _snack('Select at least one hotel service');
      return;
    }

    if (_selectedDays.isEmpty) {
      _snack('Select working days');
      return;
    }

    setState(() => _loading = true);
    var shouldResetLoading = true;

    try {
      final hotelData = _buildData();
      final updatedDraft = widget.baseDraft.copyWith(
        sectorData: {
          ...widget.baseDraft.sectorData,
          'pet_hotel': hotelData,
          'hotel': hotelData,
        },
      );

      if (!mounted) return;
      shouldResetLoading = false;
      Navigator.of(context).pop(updatedDraft);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (shouldResetLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _chips(List<String> items, List<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return FilterChip(
          label: Text(item),
          selected: selected.contains(item),
          onSelected: (_) => _toggle(selected, item),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Hotel Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_hotelName, 'Hotel Name'),
            _field(_phone, 'Phone'),
            _field(_whatsapp, 'WhatsApp'),
            _field(_instagram, 'Instagram'),
            _field(_capacity, 'Maximum capacity'),
            const SizedBox(height: 20),
            const Text(
              'Services',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _chips(_allServices, _selectedServices),
            const SizedBox(height: 20),
            const Text(
              'Amenities',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _chips(_amenityOptions, _selectedAmenities),
            const SizedBox(height: 20),
            const Text(
              'Working Days',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _chips(_days, _selectedDays),
            const SizedBox(height: 10),
            _field(_workingHours, 'Working Hours (09:00 - 18:00)'),
            const SizedBox(height: 20),
            const Text('Media', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _pickLogo,
                    icon: const Icon(Icons.image),
                    label: const Text('Logo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Photos'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
