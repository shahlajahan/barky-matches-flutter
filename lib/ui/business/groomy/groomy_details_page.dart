// lib/ui/business/groomy/groomy_details_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/business_draft.dart';
import '../../../theme/app_theme.dart';

class GroomyDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  const GroomyDetailsPage({
    super.key,
    required this.baseDraft,
  });

  @override
  State<GroomyDetailsPage> createState() => _GroomyDetailsPageState();
}

class _GroomyDetailsPageState extends State<GroomyDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  // =========================
  // SECTION 1 — BASIC INFO
  // =========================
  final TextEditingController _shopName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _instagram = TextEditingController();

  // =========================
  // SECTION 2 — SERVICES
  // =========================
  final List<String> _allServices = [
    "Bath",
    "Haircut",
    "Nail trimming",
    "Ear cleaning",
    "Teeth cleaning",
    "Full grooming",
  ];

  final List<String> _selectedServices = [];

 

  // =========================
  // SECTION 4 — WORKING HOURS
  // =========================
  final TextEditingController _workingHours = TextEditingController();

  final List<String> _days = [
    "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
  ];
  final List<String> _selectedDays = [];

  // =========================
  // SECTION 5 — FEATURES
  // =========================
  bool _homeService = false;
  bool _pickupService = false;

  // =========================
  // SECTION 6 — MEDIA
  // =========================
  String? _logoUrl;
  final List<String> _photos = [];

  // =========================
  // HELPERS
  // =========================
  void _toggle(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  @override
void initState() {
  super.initState();
  _prefill();
}

void _prefill() {
  final contact = widget.baseDraft.contact;
  final profile = widget.baseDraft.profile;

  _shopName.text = profile.displayName;
  _phone.text = contact.phone;
  _whatsapp.text = contact.whatsapp;
}

  Future<String> _uploadFile(File file, String folder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final ref = FirebaseStorage.instance
        .ref()
        .child("business_sector_docs/${user.uid}/groomy/$folder/${DateTime.now().millisecondsSinceEpoch}.jpg");

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _pickLogo() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), "logo");
      setState(() => _logoUrl = url);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;

    setState(() => _loading = true);
    try {
      final url = await _uploadFile(File(xf.path), "photos");
      setState(() => _photos.add(url));
    } finally {
      setState(() => _loading = false);
    }
  }

  // =========================
  // BUILD DATA
  // =========================
  Map<String, dynamic> _buildData() {
    return {
      "name": _shopName.text.trim(),

      "contact": {
        "phone": _phone.text.trim(),
        "whatsapp": _whatsapp.text.trim(),
        "instagram": _instagram.text.trim(),
      },

      "services": _selectedServices,

      

      "workingHours": {
        "days": _selectedDays,
        "hours": _workingHours.text.trim(),
      },

      "features": {
        "homeService": _homeService,
        "pickupService": _pickupService,
      },

      "media": {
        "logo": _logoUrl,
        "photos": _photos,
      },
    };
  }

  // =========================
  // SUBMIT
  // =========================
  Future<void> _submit() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      _snack("Select at least one service");
      return;
    }

    if (_selectedDays.isEmpty) {
      _snack("Select working days");
      return;
    }

    setState(() => _loading = true);

    try {
    final updatedDraft = widget.baseDraft.copyWith(
  sectorData: {
    ...widget.baseDraft.sectorData,

    "groomer": {
      "services": _selectedServices,

      "contact": {
        "phone": _phone.text.trim(),
        "whatsapp": _whatsapp.text.trim(),
        "instagram": _instagram.text.trim(),
      },

      "workingHours": {
        "days": _selectedDays,
        "hours": _workingHours.text.trim(),
      },

      "features": {
        "homeService": _homeService,
        "pickupService": _pickupService,
      },

      "media": {
        "logo": _logoUrl,
        "photos": _photos,
      },
    }
  },
);

if (!mounted) return;

Navigator.of(context).pop(updatedDraft);

    } catch (e, st) {
  debugPrint("❌ GROOMY ERROR => $e");
  debugPrintStack(stackTrace: st);

  _snack(e.toString());
} finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // =========================
  // UI
  // =========================
  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        validator: (v) =>
            (v == null || v.isEmpty) ? "Required" : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _chips(List<String> items, List<String> selected) {
    return Wrap(
      spacing: 8,
      children: items.map((e) {
        return FilterChip(
          label: Text(e),
          selected: selected.contains(e),
          onSelected: (_) => _toggle(selected, e),
        );
      }).toList(),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Groomy Details"),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // =========================
          // BASIC INFO
          // =========================
          _field(_shopName, "Groomy Name"),
          _field(_phone, "Phone"),
          _field(_whatsapp, "WhatsApp"),
          _field(_instagram, "Instagram"),

          const SizedBox(height: 20),

          // =========================
          // SERVICES
          // =========================
          const Text("Services", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _chips(_allServices, _selectedServices),

          const SizedBox(height: 20),

          // =========================
          // WORKING DAYS
          // =========================
          const Text("Working Days", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _chips(_days, _selectedDays),

          const SizedBox(height: 10),

          _field(_workingHours, "Working Hours (09:00 - 18:00)"),

          const SizedBox(height: 10),

          // =========================
          // FEATURES
          // =========================
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _homeService,
            onChanged: (v) => setState(() => _homeService = v),
            title: const Text("Home Service"),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pickupService,
            onChanged: (v) => setState(() => _pickupService = v),
            title: const Text("Pickup Service"),
          ),

          const SizedBox(height: 20),

          // =========================
          // MEDIA (FIXED)
          // =========================
          const Text("Media", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _pickLogo,
                  icon: const Icon(Icons.image),
                  label: const Text("Logo"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Photos"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // =========================
          // SUBMIT
          // =========================
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Continue"),
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
}