import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/utils/localization_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditDogOverlay extends StatefulWidget {
  final Dog dog;
  final VoidCallback onClose;

  const EditDogOverlay({
    super.key,
    required this.dog,
    required this.onClose,
  });

  @override
  State<EditDogOverlay> createState() => _EditDogOverlayState();
}

class _EditDogOverlayState extends State<EditDogOverlay>
    with LocalizationUtils {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _descriptionController;

  late String _selectedHealthStatus;
  late String _selectedOwnerGender;
  late bool _isNeutered;
  late bool _isAvailableForAdoption;
  late List<String> _selectedTraits;
  late List<String> _imagePaths;

  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.dog.name);
    _ageController = TextEditingController(text: widget.dog.age.toString());
    _descriptionController = TextEditingController(text: widget.dog.description);

    _selectedHealthStatus = _mapHealthStatus(widget.dog.healthStatus);
    _selectedOwnerGender = _mapOwnerGender(widget.dog.ownerGender);
    _isNeutered = widget.dog.isNeutered;
    _isAvailableForAdoption = widget.dog.isAvailableForAdoption;

    _selectedTraits = List.from(widget.dog.traits ?? []);
    _imagePaths = List.from(widget.dog.imagePaths ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─────────────────────────────
  // ✅ REAL PICK IMAGE (Gallery/Camera)
  // ─────────────────────────────
  Future<void> _pickImage() async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return;

  try {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1400,
    );

    if (file == null) return;

    final localFile = File(file.path);

    final downloadUrl = await _uploadImageToStorage(localFile);

    print("🔥 DOWNLOAD URL: $downloadUrl");

    if (!mounted) return;

    // مرحله ۱: آپدیت لیست عکس‌ها
setState(() {
  if (_imagePaths.isEmpty) {
    _imagePaths.add(downloadUrl);
  } else {
    _imagePaths[0] = downloadUrl;
  }
});

// مرحله ۲: مستقیم مدل سگ را آپدیت کن
widget.dog.imagePaths = _imagePaths;

// مرحله ۳: از AppState صدا بزن
await context.read<AppState>().saveEditedDog(widget.dog);
  } catch (e) {
    debugPrint("Upload error: $e");
  }
}

Future<String> _uploadImageToStorage(File file) async {
  final userId = widget.dog.ownerId;
  if (userId == null) {
    throw Exception("Owner ID is null");
  }

  final fileName =
      "${DateTime.now().millisecondsSinceEpoch}.jpg";

  final ref = FirebaseStorage.instance
      .ref()
      .child("dogs")
      .child(userId)
      .child(fileName);

  final uploadTask = await ref.putFile(file);

  final downloadUrl = await uploadTask.ref.getDownloadURL();

  return downloadUrl;
}
  // ─────────────────────────────
  // ✅ SAVE (keys ثابت)
  // ─────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (name.isEmpty || age == null || age <= 0) return;

    setState(() => _isSaving = true);

    final updatedDog = Dog(
      id: widget.dog.id,
      name: name,
      breed: widget.dog.breed,
      age: age,
      gender: widget.dog.gender,
      healthStatus: _selectedHealthStatus, // KEY: healthy/needsCare/underTreatment
      isNeutered: _isNeutered,
      description: _descriptionController.text.trim(),
      traits: _selectedTraits,
      ownerGender: _selectedOwnerGender, // KEY: male/female/other
      imagePaths: _imagePaths,
      isAvailableForAdoption: _isAvailableForAdoption,
      isOwner: widget.dog.isOwner,
      ownerId: widget.dog.ownerId,
      latitude: widget.dog.latitude,
      longitude: widget.dog.longitude,
    );

    await context.read<AppState>().saveEditedDog(updatedDog);

    if (!mounted) return;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // premium scroll physics
    final premiumPhysics = const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: ScrollConfiguration(
                behavior: _PremiumScrollBehavior(),
                child: SingleChildScrollView(
                  physics: premiumPhysics,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.editDog,
                        style: GoogleFonts.dancingScript(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Photos (real add/change)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Photos",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: _pickImage,
                        child: SizedBox(
                          height: 110,
                          child: _imagePaths.isEmpty
                              ? Container(
                                  width: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_a_photo,
                                          color: Colors.white),
                                      SizedBox(height: 6),
                                      Text("Add",
                                          style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                )
                              : Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: _buildDogImage(_imagePaths.first),
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.edit,
                                            size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.nameLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _whiteField(_nameController),
                      const SizedBox(height: 14),

                      // Age
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.ageLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _whiteField(
                        _ageController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // Health
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.selectHealthStatusHint,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedHealthStatus,
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(
                              value: "healthy", child: Text("Healthy")),
                          DropdownMenuItem(
                              value: "needsCare", child: Text("Needs Care")),
                          DropdownMenuItem(
                              value: "underTreatment",
                              child: Text("Under Treatment")),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedHealthStatus = v!),
                        decoration: _whiteDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // Neutered
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.neuteredLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _isNeutered,
                            onChanged: (v) =>
                                setState(() => _isNeutered = v!),
                            activeColor: Colors.white,
                          ),
                          Text("Yes",
                              style: GoogleFonts.poppins(color: Colors.white)),
                          const SizedBox(width: 12),
                          Radio<bool>(
                            value: false,
                            groupValue: _isNeutered,
                            onChanged: (v) =>
                                setState(() => _isNeutered = v!),
                            activeColor: Colors.white,
                          ),
                          Text("No",
                              style: GoogleFonts.poppins(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.descriptionLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _whiteField(
                        _descriptionController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),

                      // Traits (Animated selection + same size + ordered)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.traitsLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final traits = getDogTraits(context);
                          const spacing = 10.0;

                          // 3 ستون مرتب
                          final itemW =
                              (constraints.maxWidth - (spacing * 2)) / 3;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: traits.map((trait) {
                              final selected = _selectedTraits.contains(trait);

                              return _AnimatedTraitChip(
                                label: trait,
                                width: itemW,
                                height: 40,
                                selected: selected,
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      _selectedTraits.remove(trait);
                                    } else {
                                      _selectedTraits.add(trait);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Owner Gender
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.selectOwnerGenderHint,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedOwnerGender,
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: "male", child: Text("Male")),
                          DropdownMenuItem(
                              value: "female", child: Text("Female")),
                          DropdownMenuItem(value: "other", child: Text("Other")),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedOwnerGender = v!),
                        decoration: _whiteDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // Adoption
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.availableForAdoption,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: _isAvailableForAdoption,
                            onChanged: (v) => setState(() =>
                                _isAvailableForAdoption = v ?? false),
                            activeColor: Colors.white,
                            checkColor: Colors.black,
                          ),
                          Text(
                            l10n.availableForAdoption,
                            style:
                                GoogleFonts.poppins(color: Colors.white),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onClose,
                              child: Text(l10n.cancelButton),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDogImage(String pathOrUrl) {
    final isUrl = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');

    if (isUrl) {
      return Image.network(
        pathOrUrl,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImageBox(),
      );
    }

    final file = File(pathOrUrl);
    if (!file.existsSync()) return _fallbackImageBox();

    return Image.file(
      file,
      width: 110,
      height: 110,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackImageBox(),
    );
  }

  Widget _fallbackImageBox() {
    return Container(
      width: 110,
      height: 110,
      color: Colors.white24,
      child: const Icon(Icons.pets, color: Colors.white, size: 40),
    );
  }

  InputDecoration _whiteDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _whiteField(
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _whiteDecoration(),
    );
  }

  String _mapHealthStatus(String? value) {
    switch (value) {
      case "editDogHealthHealthy":
        return "healthy";
      case "editDogHealthNeedsCare":
        return "needsCare";
      case "editDogHealthUnderTreatment":
        return "underTreatment";
      case "healthy":
      case "needsCare":
      case "underTreatment":
        return value!;
      default:
        return "healthy";
    }
  }

  String _mapOwnerGender(String? value) {
    switch (value) {
      case "editDogOwnerGenderMale":
        return "male";
      case "editDogOwnerGenderFemale":
        return "female";
      case "editDogOwnerGenderOther":
        return "other";
      case "male":
      case "female":
      case "other":
        return value!;
      default:
        return "other";
    }
  }
}

// ─────────────────────────────
// ✅ Animated Trait Chip (selection animation)
// ─────────────────────────────
class _AnimatedTraitChip extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  const _AnimatedTraitChip({
    required this.label,
    required this.width,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        scale: selected ? 1.03 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    )
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────
// ✅ Premium scroll: remove glow, keep bounce
// ─────────────────────────────
class _PremiumScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // remove glow
  }
}