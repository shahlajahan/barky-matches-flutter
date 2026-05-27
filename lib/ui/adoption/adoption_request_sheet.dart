import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/services/adoption_request_service.dart';

class AdoptionRequestSheet extends StatefulWidget {
  final String targetType; // "dog" | "center"
  final String targetId;
  final String targetOwnerId;
  final String dogName;

  const AdoptionRequestSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetOwnerId,
    required this.dogName,
  });

  @override
  State<AdoptionRequestSheet> createState() => _AdoptionRequestSheetState();
}

class _AdoptionRequestSheetState extends State<AdoptionRequestSheet> {
  // ─────────────────────────────────────────────
  // ✅ Stepper state
  // ─────────────────────────────────────────────
  int _step = 0;
  bool _loading = false;

  final _keys = List.generate(4, (_) => GlobalKey<FormState>());

  final _picker = ImagePicker();

  // ─────────────────────────────────────────────
  // ✅ Controllers
  // ─────────────────────────────────────────────
  final _fullName = TextEditingController();
  final _phone = TextEditingController();

  final _fenceHeight = TextEditingController();
  final _experienceYears = TextEditingController(text: "0");
  final _reasonPrevDog = TextEditingController();
  final _otherPetsDetails = TextEditingController();
  final _motivation = TextEditingController();

  // ─────────────────────────────────────────────
  // ✅ Step 1 (Personal)
  // ─────────────────────────────────────────────
  String? _gender; // "male" | "female" | "other"
  String? _incomeRange; // ex: "0-2000" etc

  // ─────────────────────────────────────────────
  // ✅ Step 2 (Housing)
  // ─────────────────────────────────────────────
  String _housingType = "Apartment"; // Apartment | House | Villa
  String _ownership = "Owned"; // Owned | Rented
  bool _landlordPermission = false;

  bool _hasGarden = false;

  // ─────────────────────────────────────────────
  // ✅ Step 3 (Experience)
  // ─────────────────────────────────────────────
  bool _previousDog = false;
  bool _otherPets = false;

  // ─────────────────────────────────────────────
  // ✅ Step 4 (Financial + Commitment + Uploads)
  // ─────────────────────────────────────────────
  bool _canAffordVet = false;
  bool _emergencySavings = false;
  bool _agreeContract = false;

  // Uploads (URLs after upload)
  final List<String> _housePhotoUrls = [];
  String? _idPhotoUrl;
  String? _incomeProofUrl; // optional

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();

    _fenceHeight.dispose();
    _experienceYears.dispose();
    _reasonPrevDog.dispose();
    _otherPetsDetails.dispose();
    _motivation.dispose();

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ✅ UI helpers (same vibe as EditDogOverlay)
  // ─────────────────────────────────────────────
  InputDecoration _whiteDecoration({String? hint, String? label}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      labelText: label,
      border: const OutlineInputBorder(borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Widget _whiteField(
  TextEditingController controller, {
  TextInputType? keyboardType,
  int maxLines = 1,
  String? hint,
  String? label,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
  bool enabled = true,
}) {
  final isLastField = false; // اگر خواستی بعداً برای هر فیلد کنترل کنیم

  return SizedBox(
    height: maxLines == 1 ? 56 : null,
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,

      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,

      onEditingComplete: () {
        if (maxLines > 1) {
          FocusScope.of(context).unfocus();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },

      decoration: _whiteDecoration(hint: hint, label: label),
    ),
  );
}

  // ─────────────────────────────────────────────
  // ✅ Upload helpers (REAL upload to Firebase Storage)
  // ─────────────────────────────────────────────
  Future<String> _uploadFile({
    required File file,
    required String kind, // "house" | "id" | "income"
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.toLowerCase().endsWith(".png") ? "png" : "jpg";

    final ref = FirebaseStorage.instance
        .ref()
        .child("adoption_requests_uploads")
        .child(user.uid)
        .child("${ts}_$kind.$ext");

    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<void> _pickHousePhotos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
      if (files.isEmpty) return;

      setState(() => _loading = true);

      final urls = <String>[];
      for (final xf in files) {
        final f = File(xf.path);
        final url = await _uploadFile(file: f, kind: "house");
        urls.add(url);
      }

      if (!mounted) return;
      setState(() {
        _housePhotoUrls.addAll(urls);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickSingleDoc({required String kind}) async {
    // kind: "id" | "income"
    try {
      final xf = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (xf == null) return;

      setState(() => _loading = true);

      final url = await _uploadFile(file: File(xf.path), kind: kind);

      if (!mounted) return;
      setState(() {
        if (kind == "id") _idPhotoUrl = url;
        if (kind == "income") _incomeProofUrl = url;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────
  // ✅ Navigation / Validation
  // ─────────────────────────────────────────────
  void _next() {
    final l10n = AppLocalizations.of(context)!;
    final ok = _keys[_step].currentState?.validate() ?? false;

    // step-specific hard validations (checkbox / uploads / conditional stuff)
    if (!ok) return;

    if (_step == 1) {
      // Housing step: if rented -> landlord permission must be true
      if (_ownership == "Rented" && !_landlordPermission) {
        _toast(l10n.adoptionLandlordPermissionRequired);
        return;
      }
      // if has garden -> fence height required
      if (_hasGarden) {
        final h = int.tryParse(_fenceHeight.text.trim());
        if (h == null || h <= 0 || h > 400) {
          _toast(l10n.adoptionEnterValidFenceHeight);
          return;
        }
      }
    }

    if (_step == 2) {
      // Experience step: if previous dog -> reason required
      if (_previousDog) {
        final t = _reasonPrevDog.text.trim();
        if (t.length < 10) {
          _toast(l10n.adoptionExplainPreviousDog);
          return;
        }
      }
      // Other pets details required only if toggle ON
      if (_otherPets) {
        final t = _otherPetsDetails.text.trim();
        if (t.length < 3) {
          _toast(l10n.adoptionDescribeOtherPetsRequired);
          return;
        }
      }

      // Motivation required (legal-ish)
      final m = _motivation.text.trim();
      if (m.length < 20) {
        _toast(l10n.adoptionMotivationMinLength);
        return;
      }
    }

    if (_step < 3) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final ok = _keys[_step].currentState?.validate() ?? false;
    if (!ok) return;

    // Step 4 requirements
    if (_housePhotoUrls.isEmpty) {
      _toast(AppLocalizations.of(context)!.adoptionUploadAtLeastOnePhoto);
      return;
    }
    if (_idPhotoUrl == null) {
      _toast(AppLocalizations.of(context)!.adoptionUploadIdPhoto);
      return;
    }
    if (!_agreeContract) {
      _toast(AppLocalizations.of(context)!.adoptionAgreeContractRequired);
      return;
    }

    setState(() => _loading = true);

final user = FirebaseAuth.instance.currentUser;
if (user == null) throw Exception("Not logged in");

final requesterId = user.uid;
final requesterName = _fullName.text.trim();

    try {
      // Build structured form payload (PRO)
      final form = {
        "personalInfo": {
          "fullName": _fullName.text.trim(),
          "gender": _gender,
          "phone": _phone.text.trim(),
          "monthlyIncomeRange": _incomeRange,
        },
        "housing": {
          "housingType": _housingType,
          "ownership": _ownership, // Owned/Rented
          "landlordPermission": _ownership == "Rented" ? _landlordPermission : null,
          "hasGarden": _hasGarden,
          "fenceHeightCm": _hasGarden ? int.tryParse(_fenceHeight.text.trim()) : null,
        },
        "experience": {
          "years": int.tryParse(_experienceYears.text.trim()) ?? 0,
          "previousDog": _previousDog,
          "previousDogReason": _previousDog ? _reasonPrevDog.text.trim() : null,
          "otherPets": _otherPets,
          "otherPetsDetails": _otherPets ? _otherPetsDetails.text.trim() : null,
          "motivationMessage": _motivation.text.trim(),
        },
        "financialAndCommitment": {
          "canAffordVetExpenses": _canAffordVet,
          "emergencySavings": _emergencySavings,
          "agreeToContract": _agreeContract,
        },
        "uploads": {
          "housePhotos": _housePhotoUrls,
          "idPhoto": _idPhotoUrl,
          "proofOfIncome": _incomeProofUrl, // optional
        },
      };

      // Documents array (for your service signature)
      final documents = <String>[
  ..._housePhotoUrls,
  ?_idPhotoUrl,
  ?_incomeProofUrl,
];

      await AdoptionRequestService.createRequest(
  targetType: widget.targetType,
  targetId: widget.targetId,
  targetOwnerId: widget.targetOwnerId,
  form: form,
  documents: documents,
  //requesterId: requesterId,
  //requesterName: requesterName,
);

      if (!mounted) return;
      Navigator.pop(context);
      _toast(AppLocalizations.of(context)!.requestCreatedSuccess);
    } catch (e) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context)!.errorOccurred(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────
  // ✅ Build
  // ─────────────────────────────────────────────
  @override
Widget build(BuildContext context) {
  final premiumPhysics = const BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () {
      // ✅ Dismiss keyboard when tapping anywhere
      FocusScope.of(context).unfocus();
    },
    child: Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loading
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                child: Container(color: Colors.black54),
              ),
            ),

            // Panel (same style as EditDogOverlay)
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 680),
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
                          _buildHeader(),
                          const SizedBox(height: 14),
                          _buildStepDots(),
                          const SizedBox(height: 16),

                          // Step content
                          if (_step == 0) _stepPersonal(),
                          if (_step == 1) _stepHousing(),
                          if (_step == 2) _stepExperience(),
                          if (_step == 3) _stepFinancialAndUploads(),

                          const SizedBox(height: 18),
                          _buildBottomBar(),
                        ],
                      ),
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
  // ─────────────────────────────────────────────
  // ✅ Header + Step dots
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                l10n.adoptionRequestTitle,
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.adoptionRequestSubtitle(widget.dogName),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildStepDots() {
    Widget dot(bool active) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 26 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(_step == 0),
        dot(_step == 1),
        dot(_step == 2),
        dot(_step == 3),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Step 1: Personal Info
  // ─────────────────────────────────────────────
  Widget _stepPersonal() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _keys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.adoptionStepPersonalInfoTitle),
          const SizedBox(height: 10),

          _label(l10n.adoptionFullNameLabel),
          const SizedBox(height: 6),
          _whiteField(
            _fullName,
            hint: l10n.adoptionFullNameHint,
            validator: (v) {
              final t = (v ?? "").trim();
              if (t.length < 3) return l10n.adoptionEnterFullName;
              return null;
            },
          ),
          const SizedBox(height: 12),

          _label(l10n.genderLabel),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            dropdownColor: Colors.white,
            decoration: _whiteDecoration(),
            items: [
              DropdownMenuItem(value: "female", child: Text(l10n.genderFemale)),
              DropdownMenuItem(value: "male", child: Text(l10n.genderMale)),
              DropdownMenuItem(value: "other", child: Text(l10n.genderOther)),
            ],
            onChanged: (v) => setState(() => _gender = v),
            validator: (v) => v == null ? l10n.adoptionSelectGender : null,
          ),
          const SizedBox(height: 12),

          _label(l10n.phoneLabel),
          const SizedBox(height: 6),
          _whiteField(
            _phone,
            keyboardType: TextInputType.phone,
            hint: l10n.adoptionPhoneHint,
            validator: (v) {
              final t = (v ?? "").trim();
              if (t.length < 8) return l10n.adoptionEnterValidPhone;
              return null;
            },
          ),
          const SizedBox(height: 12),

          _label(l10n.adoptionIncomeRangeLabel),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _incomeRange,
            dropdownColor: Colors.white,
            decoration: _whiteDecoration(),
            items: [
              DropdownMenuItem(value: "0-2000", child: Text(l10n.adoptionIncomeRange0_2000)),
              DropdownMenuItem(value: "2000-5000", child: Text(l10n.adoptionIncomeRange2000_5000)),
              DropdownMenuItem(value: "5000-10000", child: Text(l10n.adoptionIncomeRange5000_10000)),
              DropdownMenuItem(value: "10000+", child: Text(l10n.adoptionIncomeRange10000Plus)),
            ],
            onChanged: (v) => setState(() => _incomeRange = v),
            validator: (v) => v == null ? l10n.adoptionSelectIncomeRange : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Step 2: Housing
  // ─────────────────────────────────────────────
  Widget _stepHousing() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _keys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.adoptionStepHousingTitle),
          const SizedBox(height: 10),

          _label(l10n.adoptionHousingTypeLabel),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _housingType,
            dropdownColor: Colors.white,
            decoration: _whiteDecoration(),
            items: [
              DropdownMenuItem(value: "Apartment", child: Text(l10n.adoptionHousingApartment)),
              DropdownMenuItem(value: "House", child: Text(l10n.adoptionHousingHouse)),
              DropdownMenuItem(value: "Villa", child: Text(l10n.adoptionHousingVilla)),
            ],
            onChanged: (v) => setState(() => _housingType = v ?? "Apartment"),
          ),
          const SizedBox(height: 12),

          _label(l10n.adoptionOwnershipLabel),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _ownership,
            dropdownColor: Colors.white,
            decoration: _whiteDecoration(),
            items: [
              DropdownMenuItem(value: "Owned", child: Text(l10n.adoptionOwnershipOwned)),
              DropdownMenuItem(value: "Rented", child: Text(l10n.adoptionOwnershipRented)),
            ],
            onChanged: (v) {
              setState(() {
                _ownership = v ?? "Owned";
                if (_ownership != "Rented") _landlordPermission = false;
              });
            },
          ),
          const SizedBox(height: 10),

          if (_ownership == "Rented")
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _landlordPermission,
              onChanged: (v) => setState(() => _landlordPermission = v),
              title: Text(
                l10n.adoptionLandlordPermissionRequired,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hasGarden,
            onChanged: (v) => setState(() => _hasGarden = v),
            title: Text(
              l10n.adoptionHasGarden,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          // Fence height only if garden ON
          if (_hasGarden) ...[
            const SizedBox(height: 6),
            _label(l10n.adoptionFenceHeightLabel),
            const SizedBox(height: 6),
            _whiteField(
              _fenceHeight,
              keyboardType: TextInputType.number,
              hint: l10n.adoptionFenceHeightHint,
              validator: (v) {
                if (!_hasGarden) return null;
                final n = int.tryParse((v ?? "").trim());
                if (n == null || n <= 0 || n > 400) return l10n.adoptionEnterValidFenceHeight;
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Step 3: Experience
  // ─────────────────────────────────────────────
  Widget _stepExperience() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _keys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.adoptionStepExperienceTitle),
          const SizedBox(height: 10),

          _label(l10n.adoptionYearsOfExperienceLabel),
          const SizedBox(height: 6),
          _whiteField(
            _experienceYears,
            keyboardType: TextInputType.number,
            hint: l10n.adoptionYearsOfExperienceHint,
            validator: (v) {
              final n = int.tryParse((v ?? "").trim());
              if (n == null || n < 0 || n > 60) return l10n.adoptionEnterYearsOfExperience;
              return null;
            },
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _previousDog,
            onChanged: (v) => setState(() => _previousDog = v),
            title: Text(
              l10n.adoptionPreviousDogQuestion,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          if (_previousDog) ...[
            const SizedBox(height: 6),
            _label(l10n.adoptionPreviousDogReasonLabel),
            const SizedBox(height: 6),
            _whiteField(
              _reasonPrevDog,
              maxLines: 2,
              hint: l10n.adoptionPreviousDogReasonHint,
              validator: (v) {
                if (!_previousDog) return null;
                final t = (v ?? "").trim();
                if (t.length < 10) return l10n.adoptionExplainPreviousDog;
                return null;
              },
            ),
          ],

          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _otherPets,
            onChanged: (v) {
              setState(() {
                _otherPets = v;
                if (!v) _otherPetsDetails.clear();
              });
            },
            title: Text(
              l10n.adoptionOtherPetsAtHome,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          // ✅ Conditional: ONLY show box when ON
          if (_otherPets) ...[
            const SizedBox(height: 6),
            _label(l10n.adoptionDescribeOtherPetsLabel),
            const SizedBox(height: 6),
            _whiteField(
              _otherPetsDetails,
              maxLines: 2,
              hint: l10n.adoptionDescribeOtherPetsHint,
              validator: (v) {
                if (!_otherPets) return null;
                final t = (v ?? "").trim();
                if (t.length < 3) return l10n.adoptionRequiredShort;
                return null;
              },
            ),
          ],

          const SizedBox(height: 12),
          _label(l10n.adoptionMotivationMessageLabel),
          const SizedBox(height: 6),
          _whiteField(
            _motivation,
            maxLines: 3,
            hint: l10n.whyDoYouWantToAdopt,
            validator: (v) {
              final t = (v ?? "").trim();
              if (t.length < 20) return l10n.adoptionMotivationMinLength;
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Step 4: Financial + Uploads + Contract
  // ─────────────────────────────────────────────
  Widget _stepFinancialAndUploads() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _keys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.adoptionStepFinancialCommitmentTitle),
          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _canAffordVet,
            onChanged: (v) => setState(() => _canAffordVet = v),
            title: Text(
              l10n.adoptionCanAffordVetExpenses,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _emergencySavings,
            onChanged: (v) => setState(() => _emergencySavings = v),
            title: Text(
              l10n.adoptionEmergencySavingsAvailable,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          const SizedBox(height: 10),
          _sectionTitle(l10n.adoptionUploadsSectionTitle),
          const SizedBox(height: 8),

          _uploadRow(
            title: l10n.adoptionHousePhotosRequiredTitle,
            subtitle: _housePhotoUrls.isEmpty
                ? l10n.adoptionUploadAtLeastOnePhoto
                : l10n.adoptionUploadedCount(_housePhotoUrls.length),
            primaryText: l10n.adoptionUploadButton,
            onPrimary: _loading ? null : _pickHousePhotos,
            secondaryText: _housePhotoUrls.isEmpty ? null : l10n.adoptionClearButton,
            onSecondary: _loading
                ? null
                : () => setState(() => _housePhotoUrls.clear()),
          ),
          const SizedBox(height: 10),

          _uploadRow(
            title: l10n.adoptionIdPhotoRequiredTitle,
            subtitle: _idPhotoUrl == null ? l10n.adoptionNotUploaded : l10n.adoptionUploaded,
            primaryText: _idPhotoUrl == null ? l10n.adoptionUploadButton : l10n.adoptionReplaceButton,
            onPrimary: _loading ? null : () => _pickSingleDoc(kind: "id"),
            secondaryText: _idPhotoUrl == null ? null : l10n.adoptionRemoveButton,
            onSecondary: _loading
                ? null
                : () => setState(() => _idPhotoUrl = null),
          ),
          const SizedBox(height: 10),

          _uploadRow(
            title: l10n.adoptionProofOfIncomeOptionalTitle,
            subtitle: _incomeProofUrl == null ? l10n.adoptionOptionalLabel : l10n.adoptionUploaded,
            primaryText: _incomeProofUrl == null ? l10n.adoptionUploadButton : l10n.adoptionReplaceButton,
            onPrimary: _loading ? null : () => _pickSingleDoc(kind: "income"),
            secondaryText: _incomeProofUrl == null ? null : l10n.adoptionRemoveButton,
            onSecondary: _loading
                ? null
                : () => setState(() => _incomeProofUrl = null),
          ),

          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agreeContract,
            onChanged: (v) => setState(() => _agreeContract = v ?? false),
            activeColor: Colors.white,
            checkColor: Colors.black,
            title: Text(
              l10n.adoptionAgreeContractRequiredLabel,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          // Validator hook (so Form.validate can fail if needed)
          // (We still hard-check before submit, but this adds visual correctness.)
          Builder(
            builder: (_) {
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Bottom bar (Back/Next/Send Request)
  // ─────────────────────────────────────────────
  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    final isLast = _step == 3;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _loading ? null : _back,
            child: Text(_step == 0 ? l10n.cancel : l10n.backButton),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _loading ? null : (isLast ? _submit : _next),
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isLast ? l10n.sendRequestButton : l10n.adoptionNextButton),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Small UI blocks
  // ─────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _uploadRow({
    required String title,
    required String subtitle,
    required String primaryText,
    required VoidCallback? onPrimary,
    String? secondaryText,
    VoidCallback? onSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onPrimary,
            child: Text(primaryText),
          ),
          if (secondaryText != null) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryText),
            ),
          ],
        ],
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
