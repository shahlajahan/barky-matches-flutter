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
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';

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
  final l10n = AppLocalizations.of(context)!;
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
            title: Text(l10n.chooseFromGallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(l10n.takeAPhoto),
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

    debugPrint("🔥 DOWNLOAD URL: $downloadUrl");

    if (!mounted) return;

    // مرحله ۱: آپدیت لیست عکس‌ها
setState(() {
  _imagePaths.add(downloadUrl); // ✅ فقط اضافه کن، نه replace
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

  final ext = file.path.split('.').last; // 👈 گرفتن پسوند واقعی

final fileName =
  "${DateTime.now().millisecondsSinceEpoch}.$ext";

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
                          l10n.photosLabel,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      SizedBox(
  height: 110,
  child: Row(
    children: [

      /// ➕ ADD BUTTON
      GestureDetector(
        onTap: _pickImage,

        child: Container(
          width: 100,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),

      /// 🎥 ADD VIDEO BUTTON
GestureDetector(
  onTap: _pickVideo,
  child: Container(
    width: 100,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Icon(Icons.videocam, color: Colors.white, size: 26),
    ),
  ),
),

      /// 🎞 SLIDER
      Expanded(
        child: _imagePaths.isEmpty
            ? Center(
                child: Text(
                  l10n.noMedia,
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : PageView.builder(
                itemCount: _imagePaths.length,
                itemBuilder: (context, index) {
                  final path = _imagePaths[index];
final lower = path.toLowerCase(); // ✅ اینو اضافه کن
final isVideo = lower.contains('.mp4');

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [

                        /// 🖼 IMAGE
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: isVideo
    ? Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.play_circle_fill,
              color: Colors.white, size: 30),
        ),
      )
    : _buildDogImage(path),
                        ),

                        /// 🗑 DELETE BUTTON
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imagePaths.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  );
                },
              ),
      ),
    ],
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
                        initialValue: _selectedHealthStatus,
                        dropdownColor: Colors.white,
                        items: [
                          DropdownMenuItem(
                              value: "healthy",
                              child: Text(l10n.editDogHealthHealthy)),
                          DropdownMenuItem(
                              value: "needsCare",
                              child: Text(l10n.editDogHealthNeedsCare)),
                          DropdownMenuItem(
                              value: "underTreatment",
                              child: Text(l10n.editDogHealthUnderTreatment)),
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
                          Text(l10n.yes,
                              style: GoogleFonts.poppins(color: Colors.white)),
                          const SizedBox(width: 12),
                          Radio<bool>(
                            value: false,
                            groupValue: _isNeutered,
                            onChanged: (v) =>
                                setState(() => _isNeutered = v!),
                            activeColor: Colors.white,
                          ),
                          Text(l10n.no,
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
                        initialValue: _selectedOwnerGender,
                        dropdownColor: Colors.white,
                        items: [
                          DropdownMenuItem(
                              value: "male",
                              child: Text(l10n.editDogOwnerGenderMale)),
                          DropdownMenuItem(
                              value: "female",
                              child: Text(l10n.editDogOwnerGenderFemale)),
                          DropdownMenuItem(
                              value: "other",
                              child: Text(l10n.editDogOwnerGenderOther)),
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

  Future<void> _pickVideo() async {
  try {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (file == null) return;

    final localFile = File(file.path);

    final downloadUrl = await _uploadImageToStorage(localFile); // همونو استفاده کن

    if (!mounted) return;

    setState(() {
      _imagePaths.add(downloadUrl); // ✅ multi media
    });

    widget.dog.imagePaths = _imagePaths;
    await context.read<AppState>().saveEditedDog(widget.dog);

  } catch (e) {
    debugPrint("Video upload error: $e");
  }
}

  Widget _buildDogImage(String pathOrUrl) {
  final isUrl =
      pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://');

  if (isUrl) {
    return SmartMedia(
      url: pathOrUrl, // ✅ مهم
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

class VideoPreviewWidget extends StatefulWidget {
  final String url;

  const VideoPreviewWidget({super.key, required this.url});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  Uint8List? _thumbnail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        quality: 70,
      );

      if (!mounted) return;

      setState(() {
        _thumbnail = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(url: widget.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _openPlayer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_thumbnail != null)
            Image.memory(_thumbnail!, fit: BoxFit.cover)
          else
            Container(color: Colors.black),

          const Icon(
            Icons.play_circle_fill,
            size: 40,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String url;

  const FullScreenVideoPlayer({super.key, required this.url});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;

  @override
void initState() {
  super.initState();

  _controller = widget.url.startsWith('http')

      ? VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
        )

      : VideoPlayerController.file(
          File(widget.url),
        );

  _controller!
    ..initialize().then((_) {

      if (mounted) {
        setState(() {});
      }

    })

    ..play()

    ..setLooping(true);
}
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          Center(
            child: _controller != null &&
                    _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : const CircularProgressIndicator(),
          ),

          /// ❌ CLOSE BUTTON
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
