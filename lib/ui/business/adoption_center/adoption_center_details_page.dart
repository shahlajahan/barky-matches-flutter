// lib/ui/business/adoption_center/adoption_center_details_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/business_draft.dart';

class AdoptionCenterDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  const AdoptionCenterDetailsPage({
    super.key,
    required this.baseDraft,
  });

  @override
  State<AdoptionCenterDetailsPage> createState() =>
      _AdoptionCenterDetailsPageState();
}

class _AdoptionCenterDetailsPageState
    extends State<AdoptionCenterDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  // =========================
  // SECTION 1 — BASIC INFO
  // =========================

  final TextEditingController _centerName =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  final TextEditingController _whatsapp =
      TextEditingController();

  final TextEditingController _instagram =
      TextEditingController();

  // =========================
  // SECTION 2 — SERVICES
  // =========================

  final List<String> _allServices = [
    "Dog Adoption",
    "Cat Adoption",
    "Puppy Rescue",
    "Senior Pet Adoption",
    "Special Needs Pets",
    "Temporary Foster Care",
    "Rescue Support",
    "Vaccinated Pets",
    "International Adoption",
  ];

  final List<String> _selectedServices = [];

  // =========================
  // SECTION 3 — PET TYPES
  // =========================

  final List<String> _petTypes = [
    "Dog",
    "Cat",
    "Bird",
    "Rabbit",
    "Other",
  ];

  final List<String> _selectedPetTypes = [];

  // =========================
  // SECTION 4 — WORKING HOURS
  // =========================

  final TextEditingController _workingHours =
      TextEditingController();

  final List<String> _days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  final List<String> _selectedDays = [];

  // =========================
  // SECTION 5 — FEATURES
  // =========================

  bool _vetCheckIncluded = false;

  bool _homeVisitAvailable = false;

  bool _transportSupport = false;

  bool _fosterSupport = false;

  // =========================
  // SECTION 6 — MEDIA
  // =========================

  String? _logoUrl;

  final List<String> _photos = [];

  // =========================
  // HELPERS
  // =========================

  void _toggle(
    List<String> list,
    String value,
  ) {
    setState(() {
      list.contains(value)
          ? list.remove(value)
          : list.add(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _centerName.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _workingHours.dispose();
    super.dispose();
  }

  void _prefill() {
    final contact = widget.baseDraft.contact;
    final profile = widget.baseDraft.profile;

    _centerName.text = profile.displayName;

    _phone.text = contact.phone;

    _whatsapp.text = contact.whatsapp;
  }

  Future<String> _uploadFile(
    File file,
    String folder,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child(
      "business_sector_docs/${user.uid}/adoption_center/$folder/${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    await ref.putFile(file);

    return ref.getDownloadURL();
  }

  Future<void> _pickLogo() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (xf == null) return;

    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final url = await _uploadFile(
        File(xf.path),
        "logo",
      );

      if (!mounted) return;

      setState(() {
        _logoUrl = url;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (xf == null) return;

    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final url = await _uploadFile(
        File(xf.path),
        "photos",
      );

      if (!mounted) return;

      setState(() {
        _photos.add(url);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // =========================
  // BUILD DATA
  // =========================

  Map<String, dynamic> _buildData() {
    final weekendOpen =
        _selectedDays.contains("Saturday") ||
            _selectedDays.contains("Sunday");

    return {
      "displayName":
          _centerName.text.trim(),

      "description":
          widget.baseDraft.profile.description,

      "logo": _logoUrl,

      "coverImage":
          _photos.isNotEmpty
              ? _photos.first
              : null,

      "specialties":
          _selectedServices,

      "petTypes":
          _selectedPetTypes,

      "contact": {
        "phone":
            _phone.text.trim(),

        "whatsapp":
            _whatsapp.text.trim(),

        "instagram":
            _instagram.text.trim(),
      },

      "services": {
        "offeredServices":
            _selectedServices,
      },

      "workingHours": {
        "workingDays":
            _selectedDays,

        "workingHours":
            _workingHours.text.trim(),

        "weekendOpen":
            weekendOpen,
      },

      "operationalDetails": {
        "vetCheckIncluded":
            _vetCheckIncluded,

        "homeVisitAvailable":
            _homeVisitAvailable,

        "transportSupport":
            _transportSupport,

        "fosterSupport":
            _fosterSupport,
      },

      "profileContent": {
        "logoUrl": _logoUrl,

        "photoUrls": _photos,

        "socialMedia": {
          "whatsapp":
              _whatsapp.text.trim(),

          "instagram":
              _instagram.text.trim(),
        },
      },
    };
  }

  // =========================
  // SUBMIT
  // =========================

  Future<void> _submit() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedServices.isEmpty) {
      _snack(
        "Select at least one service",
      );
      return;
    }

    if (_selectedPetTypes.isEmpty) {
      _snack(
        "Select at least one pet type",
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      _snack(
        "Select working days",
      );
      return;
    }

    setState(() => _loading = true);

    var shouldResetLoading = true;

    try {
      final adoptionData =
          _buildData();

      final updatedDraft =
          widget.baseDraft.copyWith(
        sectorData: {
          ...widget.baseDraft.sectorData,

          "adoptionCenter":
              adoptionData,

          "adoption_center":
              adoptionData,
        },
      );

      if (!mounted) return;

      shouldResetLoading = false;

      Navigator.of(context)
          .pop(updatedDraft);
    } catch (e, st) {
      debugPrint(
        "❌ ADOPTION CENTER ERROR => $e",
      );

      debugPrintStack(
        stackTrace: st,
      );

      _snack(e.toString());
    } finally {
      if (shouldResetLoading &&
          mounted) {
        setState(
          () => _loading = false,
        );
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }

  // =========================
  // UI HELPERS
  // =========================

  Widget _field(
    TextEditingController c,
    String label,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        validator: (v) {
          if (v == null || v.isEmpty) {
            return "Required";
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
        ),
      ),
    );
  }

  Widget _chips(
    List<String> items,
    List<String> selected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        return FilterChip(
          label: Text(e),

          selected:
              selected.contains(e),

          onSelected: (_) =>
              _toggle(selected, e),
        );
      }).toList(),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Adoption Center Details",
        ),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding:
              const EdgeInsets.all(16),

          children: [
            // =========================
            // BASIC INFO
            // =========================

            _field(
              _centerName,
              "Center Name",
            ),

            _field(
              _phone,
              "Phone",
            ),

            _field(
              _whatsapp,
              "WhatsApp",
            ),

            _field(
              _instagram,
              "Instagram",
            ),

            const SizedBox(height: 20),

            // =========================
            // SERVICES
            // =========================

            const Text(
              "Adoption Services",
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            _chips(
              _allServices,
              _selectedServices,
            ),

            const SizedBox(height: 24),

            // =========================
            // PET TYPES
            // =========================

            const Text(
              "Pet Types",
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            _chips(
              _petTypes,
              _selectedPetTypes,
            ),

            const SizedBox(height: 24),

            // =========================
            // WORKING DAYS
            // =========================

            const Text(
              "Working Days",
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            _chips(
              _days,
              _selectedDays,
            ),

            const SizedBox(height: 12),

            _field(
              _workingHours,
              "Working Hours (09:00 - 18:00)",
            ),

            const SizedBox(height: 20),

            // =========================
            // FEATURES
            // =========================

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value:
                  _vetCheckIncluded,

              onChanged: (v) {
                setState(() {
                  _vetCheckIncluded = v;
                });
              },

              title: const Text(
                "Vet Check Included",
              ),
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value:
                  _homeVisitAvailable,

              onChanged: (v) {
                setState(() {
                  _homeVisitAvailable = v;
                });
              },

              title: const Text(
                "Home Visit Available",
              ),
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value:
                  _transportSupport,

              onChanged: (v) {
                setState(() {
                  _transportSupport = v;
                });
              },

              title: const Text(
                "Transport Support",
              ),
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value: _fosterSupport,

              onChanged: (v) {
                setState(() {
                  _fosterSupport = v;
                });
              },

              title: const Text(
                "Foster Support",
              ),
            ),

            const SizedBox(height: 24),

            // =========================
            // MEDIA
            // =========================

            const Text(
              "Media",
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : _pickLogo,

                    icon:
                        const Icon(
                      Icons.image,
                    ),

                    label:
                        const Text(
                      "Logo",
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : _pickPhoto,

                    icon:
                        const Icon(
                      Icons.photo_library,
                    ),

                    label:
                        const Text(
                      "Photos",
                    ),
                  ),
                ),
              ],
            ),

            if (_logoUrl != null) ...[
              const SizedBox(height: 16),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                child: Image.network(
                  _logoUrl!,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 16),

              SizedBox(
                height: 90,

                child: ListView.builder(
                  scrollDirection:
                      Axis.horizontal,

                  itemCount:
                      _photos.length,

                  itemBuilder:
                      (context, index) {
                    return Container(
                      width: 90,
                      margin:
                          const EdgeInsets.only(
                        right: 10,
                      ),

                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),

                        child: Image.network(
                          _photos[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 30),

            // =========================
            // SUBMIT
            // =========================

            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),

              onPressed:
                  _loading ? null : _submit,

              child: _loading
                  ? const CircularProgressIndicator(
                      color:
                          Colors.white,
                    )
                  : const Text(
                      "Continue",
                    ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}