

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'dog.dart';
import 'edit_dog_dialog.dart';
import 'app_state.dart';
import 'other_user_dog_page.dart';
import 'play_date_scheduling_page.dart';
import 'dart:io';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'ui/common/report_button.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/ui/common/pages/submit_complaint_page.dart';

enum DogCardMode {
  normal,
  playdate,
  compact, 
  adoption,  // 🔥 NEW
}


class DogCard extends StatefulWidget {
  final DogCardMode mode;
  final Dog dog;
  final List<Dog> allDogs;
  final String currentUserId;
  final List<Dog>? favoriteDogs;
  final String? selectedRequesterDogId;
  final void Function(String?)? onRequesterDogChanged;
  final void Function(Dog)? onToggleFavorite;
  final void Function(Dog)? onDogUpdated;
  final VoidCallback? onAdopt;
  final Dog? Function()? getSelectedDog;
  final bool showDogSelection;
  final List<Map<String, dynamic>> likers;
  final bool enableChat;
  final bool enableLike;
  final bool enableNavigation;
  final bool enableEdit;
  final bool enablePlaydate;
  final bool disableTap;
  

  final VoidCallback? onCardTap;   // ✅ اینجا

  const DogCard({
  super.key,
  required this.dog,
  required this.allDogs,
  required this.currentUserId,
  this.favoriteDogs,
  this.selectedRequesterDogId,
  this.onRequesterDogChanged,
  this.onToggleFavorite,
  this.onDogUpdated,
  this.onAdopt,
  this.getSelectedDog,
  this.showDogSelection = true,
  required this.likers,
  this.enableChat = true,
  this.enableLike = true,
  this.enableNavigation = true,
  this.enableEdit = true,
  this.enablePlaydate = true,
  this.mode = DogCardMode.normal,
  this.onCardTap, // ✅ اینجا
  this.disableTap = false,
});

  @override
  _DogCardState createState() => _DogCardState();
}

class _DogCardState extends State<DogCard>
    with AutomaticKeepAliveClientMixin {

  late AppLocalizations localizations;
bool _showHeart = false;
double _heartScale = 0.5;
  bool _isEditing = false;
  bool _isDialogOpen = false;
  double _dragX = 0;
bool get _enableHero => widget.mode == DogCardMode.normal;
  late ScaffoldMessengerState _scaffoldMessenger;

  int _likeCount = 0;
  bool _isDisliked = false;

  @override
  bool get wantKeepAlive => true;
Widget _buildImageWrapper(String? imagePath) {
  return RepaintBoundary(
    child: imagePath != null
        ? _enableHero
            ? Hero(
                tag: "dog_${widget.dog.id}",
                child: _buildExpandedDogImage(imagePath),
              )
            : _buildExpandedDogImage(imagePath)
        : _fallbackImage(),
  );
}
  Widget _buildDogImage(String imagePath) {
    
    return imagePath.startsWith('http')
        ? CachedNetworkImage(
  imageUrl: imagePath,
  width: 50,
  height: 50,
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  memCacheWidth: 300,
  memCacheHeight: 300,
  placeholder: (context, url) => Container(
    color: Colors.grey.shade200,
  ),
            errorWidget: (context, url, error) {
              if (kDebugMode && false) {
                print('DogCard - Error loading image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              );
            },
          )
        : Image(
            image: FileImage(File(imagePath)),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode && false) {
                print('DogCard - Error loading file image: $error');
              }
              return const Image(
                image: AssetImage('assets/image/default_dog.png'),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              );
            },
          );
  }
  void _triggerLikeAnimation() {
  setState(() {
    _showHeart = true;
    _heartScale = 1.2;
  });

  Future.delayed(const Duration(milliseconds: 200), () {
    if (!mounted) return;
    setState(() {
      _heartScale = 1.0;
    });
  });

  Future.delayed(const Duration(milliseconds: 800), () {
    if (!mounted) return;
    setState(() {
      _showHeart = false;
    });
  });
}

Widget _buildActionButtons({
  required bool isOwner,
  required bool isFavorite,
  Color? iconColor,
}) {
  final color = iconColor ?? AppTheme.primary;

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [

      // ❤️ Like
      if (!isOwner && widget.enableLike)
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppTheme.primary : AppTheme.muted,
          ),
          onPressed: () =>
              widget.onToggleFavorite?.call(widget.dog),
        ),

      // 📅 Playdate
      if (!isOwner &&
          widget.enablePlaydate &&
          !widget.dog.isAvailableForAdoption)
        IconButton(
          icon: const Icon(Icons.calendar_today),
          color: color,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayDateSchedulingPage(
                  selectedDog: widget.dog,
                  allDogs: widget.allDogs,
                ),
              ),
            );
          },
        ),

      // 💬 Chat
      if (!isOwner && widget.enableChat)
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          color: color,
          onPressed: () {
            _scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  localizations.chatWithOwner(widget.dog.name),
                  style: AppTheme.body(),
                ),
              ),
            );
          },
        ),

    ],
  );
}

  Widget _buildCompactDogCard(BuildContext context) {
  final imagePath = widget.dog.imagePaths.isNotEmpty 
      ? widget.dog.imagePaths.first 
      : null;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: widget.disableTap
            ? null
            : (widget.onCardTap ??
                () {
                  FocusScope.of(context).unfocus();
                  final ownerId = widget.dog.ownerId;
                  if (ownerId == null || ownerId.isEmpty) return;
                  context.read<AppState>().setPlaymateProfile(
                    ownerId,
                    widget.allDogs,
                  );
                }),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow(),
          ),
          child: Row(
            children: [
              // عکس با wrapper
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: _buildImageWrapper(imagePath),
                ),
              ),
              const SizedBox(width: 14),

              // اطلاعات متنی
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.dog.name,
                            style: AppTheme.h2(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${widget.dog.age}y',
                          style: AppTheme.caption(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translateBreed(widget.dog.breed),
                      style: AppTheme.body(color: AppTheme.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.dog.distanceKm != null
                          ? "${widget.dog.distanceKm!.toStringAsFixed(1)} km away"
                          : "distance unknown",
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 6),

                    // تگ‌ها
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMiniInfoTag(
                          icon: Icons.pets,
                          text: translateGender(widget.dog.gender),
                        ),
                        _buildTag(translateHealthStatus(widget.dog.healthStatus)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _fallbackImage() {
  return Container(
    width: double.infinity,
    height: 180,
    color: Colors.grey.shade200,
    child: const Icon(
      Icons.pets,
      size: 60,
      color: Colors.grey,
    ),
  );
}

 Widget _buildExpandedDogImage(String imagePath) {
  // ✅ اگر URL فایربیس بود
  if (imagePath.startsWith('http')) {
    return CachedNetworkImage(
  imageUrl: imagePath,
  width: double.infinity,
  height: 180,
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  memCacheWidth: 600,
  memCacheHeight: 600,
  placeholder: (context, url) =>
      Container(color: Colors.grey.shade200),
  errorWidget: (context, url, error) {
    return _fallbackImage();
  },
);
  }

  // ❌ اگر tmp path قدیمی iOS بود → اصلاً تلاش نکن load کنی
  if (imagePath.contains('/private/') ||
      imagePath.contains('/tmp/') ||
      imagePath.contains('image_picker')) {
    if (kDebugMode && false) {
      print('DogCard - Ignoring old local tmp path');
    }
    return _fallbackImage();
  }

  // ✅ اگر local file واقعی و دائمی بود
  return Image.file(
    File(imagePath),
    width: double.infinity,
    height: 180,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
     if (kDebugMode && false) {
        print('DogCard - File image error: $error');
      }
      return _fallbackImage();
    },
  );
}

  @override
  void initState() {
    super.initState();
    if (kDebugMode && false) {
      //print('DogCard - Initializing for dog: ${widget.dog.name}, ID: ${widget.dog.id}');
      print('DogCard - Likers received: ${widget.likers}');
       _updateLikesAndFavorites();
    }
  }

  String translateGender(String gender) {
    if (gender.isEmpty) {
      return localizations.unknownGender ?? 'Unknown';
    }

    final g = gender.toLowerCase().trim();

    if (g.contains('male') || g.contains('نر')) {
      return localizations.genderMale ?? 'Male';
    }

    if (g.contains('female') || g.contains('ماده')) {
      return localizations.genderFemale ?? 'Female';
    }

    return gender;
  }

  String translateHealthStatus(String status) {
    if (status.isEmpty) {
      return localizations.unknownStatus ?? 'Unknown';
    }

    final s = status.toLowerCase().trim();

    if (s.contains('healthy') || s.contains('سالم')) {
      return localizations.healthHealthy ?? 'Healthy';
    }

    if (s.contains('care') || s.contains('نیاز')) {
      return localizations.healthNeedsCare ?? 'Needs Care';
    }

    if (s.contains('treatment') || s.contains('درمان')) {
      return localizations.healthUnderTreatment ?? 'Under Treatment';
    }

    return status;
  }

  String translateBreed(String breedKey) {
    if (breedKey.isEmpty) {
      return localizations.unknownBreed ?? 'Unknown Breed';
    }

    switch (breedKey) {
      case 'breedAfghanHound':
        return localizations.breedAfghanHound ?? 'Afghan Hound';
      case 'breedAiredaleTerrier':
        return localizations.breedAiredaleTerrier ?? 'Airedale Terrier';
      default:
        final parts = breedKey.split('breed');
        return parts.length > 1 ? parts[1] : breedKey;
    }
  }

  

  void _updateLikesAndFavorites() {
  final appState = Provider.of<AppState>(context, listen: false);
  final userId = widget.currentUserId;
  final dogKey = widget.dog.id;
  final likes = appState.likesNotifier.value;
  final userLikes = likes[userId] ?? [];

  final newIsDisliked = userLikes.contains('dislike_$dogKey');

  final newLikeCount = likes.values.fold(
    0,
    (count, likesList) => count + (likesList.contains(dogKey) ? 1 : 0),
  );

  if (!mounted) return;

  // حالا مقایسه امن است
  if (_likeCount != newLikeCount || _isDisliked != newIsDisliked) {
    setState(() {
      _likeCount = newLikeCount;
      _isDisliked = newIsDisliked;
    });
  }
}

  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  // 🌍 localization
  localizations = AppLocalizations.of(context)!;

  // 📣 scaffold messenger (safe)
  _scaffoldMessenger = ScaffoldMessenger.of(context);

  
}

// ===============================
// ✏️ EDIT DOG
// ===============================
Future<void> _openEditDialog(BuildContext context) async {
  if (widget.onDogUpdated == null) return;

  // 🚫 جلوگیری از double open
  if (_isEditing || _isDialogOpen) return;

  setState(() {
    _isEditing = true;
    _isDialogOpen = true;
  });

  try {
    if (kDebugMode && false) {
      debugPrint("✏️ Opening edit dialog for ${widget.dog.name}");
    }

    context.read<AppState>().openEditDog(widget.dog);

  } catch (e, stack) {
    if (kDebugMode && false) {
      debugPrint("❌ Edit dialog error: $e");
      debugPrint("$stack");
    }

    if (mounted) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            "Error opening edit",
            style: AppTheme.body(),
          ),
        ),
      );
    }
  } finally {
    if (!mounted) {
      _isDialogOpen = false;
      return;
    }

    setState(() {
      _isEditing = false;
      _isDialogOpen = false;
    });
  }
}

// ===============================
// 🐶 ADOPTION CARD (CLEAN + FAST)
// ===============================
Widget _buildAdoptionDogCard(BuildContext context) {
  final imagePath = widget.dog.imagePaths.isNotEmpty
      ? widget.dog.imagePaths.first
      : null;

  return RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===============================
            // 🖼 IMAGE (OPTIMIZED)
            // ===============================
          SizedBox(
  height: 180,
  width: double.infinity,
  child: _buildImageWrapper(imagePath),
),

            // ===============================
            // 📄 CONTENT
            // ===============================
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🐶 NAME
                  Text(
                    widget.dog.name,
                    style: AppTheme.h1(),
                  ),

                  const SizedBox(height: 4),

                  // 🎂 AGE + BREED
                  Text(
                    '${widget.dog.age}y • ${translateBreed(widget.dog.breed)}',
                    style: AppTheme.body(color: AppTheme.muted),
                  ),

                  const SizedBox(height: 12),

                  // 🏷 TAGS
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildTag(translateGender(widget.dog.gender)),
                      _buildTag(translateHealthStatus(widget.dog.healthStatus)),

                      if (widget.dog.isNeutered)
                        _buildTag(localizations.neutered),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===============================
                  // 🟡 CTA BUTTON
                  // ===============================
                  if (widget.onAdopt != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (kDebugMode && false) {
                            debugPrint("🐶 Adoption tapped → ${widget.dog.id}");
                          }

                          widget.onAdopt?.call();
                        },
                        child: Text(
                          "Send Adoption Request",
                          style: AppTheme.body(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  
@override
Widget build(BuildContext context) {
  super.build(context); 
  // 🔥 STEP 1 — Compact mode handler
  if (widget.mode == DogCardMode.compact) {
    return _buildCompactDogCard(context);
  }

  if (widget.mode == DogCardMode.playdate) {
    return _buildPlaydateDogCard(context);
  }

  if (widget.mode == DogCardMode.adoption) {
    return _buildAdoptionDogCard(context);
  }

  final appState = context.read<AppState>();
  final isOwner = widget.dog.ownerId == widget.currentUserId;
  final isFavorite = widget.favoriteDogs
    ?.any((d) => d.id == widget.dog.id) ?? false;

  final imagePath =
      widget.dog.imagePaths.isNotEmpty ? widget.dog.imagePaths.first : null;

  return RepaintBoundary(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Material(
      color: const Color(0xFFFFFBFC),
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────
              // 🖼 Image
              // ─────────────────────────
              SizedBox(
  height: 180,
  width: double.infinity,
  child: _buildImageWrapper(imagePath),
),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─────────────────────────
                    // 🐶 Name + Age
                    // ─────────────────────────
                    Row(
  children: [

    // 🐶 NAME
    Expanded(
      child: Text(
        widget.dog.name,
        style: AppTheme.h1(),
      ),
    ),

    // ✏️ Edit
    if (isOwner && widget.enableEdit)
      IconButton(
        icon: const Icon(Icons.edit),
        color: AppTheme.primary,
        onPressed: () {
          _openEditDialog(context);
        },
      ),

    // ⋮ MENU
    if (!isOwner)
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == "report") {
            showModalBottomSheet(
              context: context,
              builder: (_) => ReportButton(
                type: "dog",
                targetId: widget.dog.id,
                targetOwnerId: widget.dog.ownerId ?? "",
              ),
            );
          }

          if (value == "complaint") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubmitComplaintPage(
                  targetType: "dog",
                  targetId: widget.dog.id,
                ),
              ),
            );
          }

          if (value == "block") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Block feature coming soon")),
            );
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: "report",
            child: Text("Report"),
          ),
          PopupMenuItem(
            value: "complaint",
            child: Text("Submit Complaint"),
          ),
          PopupMenuItem(
            value: "block",
            child: Text("Block User"),
          ),
        ],
      ),

    // 🎂 AGE
    Text(
      '${widget.dog.age}y',
      style: AppTheme.caption(),
    ),
  ],
),
                    const SizedBox(height: 6),

                    Text(
                      translateBreed(widget.dog.breed),
                      style: AppTheme.body(color: AppTheme.muted),
                    ),

                    const SizedBox(height: 12),

                    // ─────────────────────────
                    // 🐶 Gender + Owner Gender
                    // ─────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildMiniInfoTag(
                          icon: Icons.pets,
                          text: translateGender(widget.dog.gender),
                        ),
                        if (widget.dog.ownerGender != null &&
                            widget.dog.ownerGender!.isNotEmpty)
                          _buildMiniInfoTag(
                            icon: Icons.person_outline,
                            text:
                                "Owner: ${translateGender(widget.dog.ownerGender!)}",
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─────────────────────────
                    // 🏷 Tags
                    // ─────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildTag(
                          translateHealthStatus(widget.dog.healthStatus),
                        ),
                        _buildTag(
                          widget.dog.isNeutered
                              ? localizations.neutered
                              : localizations.notNeutered,
                        ),
                        if (widget.dog.isAvailableForAdoption)
                          _buildTag(
                            localizations.forAdoption,
                            color: AppTheme.accent,
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─────────────────────────
                    // 🔘 Actions
                    // ─────────────────────────
                    _buildActionButtons(
                      isOwner: isOwner,
                      isFavorite: isFavorite,
                    ),

                    if (widget.dog.isAvailableForAdoption) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            if (widget.onAdopt != null) {
                              widget.onAdopt!();
                            }
                          },
                          child: Text(
                            localizations.forAdoption,
                            style: AppTheme.body(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    ),
  );
}



Widget _buildTag(String text, {Color? color}) {
  final baseColor = color ?? AppTheme.primary;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: baseColor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: baseColor.withOpacity(0.25),
        width: 0.8,
      ),
    ),
    child: Text(
      text,
      style: AppTheme.caption(color: baseColor),
    ),
  );
}

 Widget _buildPlaydateDogCard(BuildContext context) {
  final appState = context.watch<AppState>();
  final isOwner = widget.dog.ownerId == widget.currentUserId;

  final imagePath =
      widget.dog.imagePaths.isNotEmpty ? widget.dog.imagePaths.first : null;

  final isFavorite = (widget.favoriteDogs ?? appState.favoriteDogs)
      .any((d) => d.id == widget.dog.id);

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E1746), Color(0xFF9E1B4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: imagePath != null
                  ? _buildExpandedDogImage(imagePath)
                  : Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.pets, size: 48, color: Colors.white70),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // 🔥🔥🔥 HEADER (اسم + دات منو کنار هم)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.dog.name,
                          style: GoogleFonts.dancingScript(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == "report") {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => ReportButton(
                                type: "dog",
                                targetId: widget.dog.id,
                                targetOwnerId: widget.dog.ownerId ?? "",
                              ),
                            );
                          }

                          if (value == "complaint") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubmitComplaintPage(
                                  targetType: "dog",
                                  targetId: widget.dog.id,
                                ),
                              ),
                            );
                          }

                          if (value == "block") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Block coming soon")),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: "report", child: Text("Report")),
                          PopupMenuItem(value: "complaint", child: Text("Complaint")),
                          PopupMenuItem(value: "block", child: Text("Block")),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '🎂 ${widget.dog.age} ${localizations.years} • ${translateBreed(widget.dog.breed)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pillDark(icon: Icons.pets, text: translateGender(widget.dog.gender)),
                      if (widget.dog.ownerGender != null &&
                          widget.dog.ownerGender!.trim().isNotEmpty)
                        _pillDark(
                          icon: Icons.person_outline,
                          text: 'Owner: ${translateGender(widget.dog.ownerGender!)}',
                        ),
                      _pillDark(text: translateHealthStatus(widget.dog.healthStatus)),
                      _pillDark(text: widget.dog.isNeutered ? localizations.neutered : localizations.notNeutered),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _buildActionButtons(
                    isOwner: isOwner,
                    isFavorite: isFavorite,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
// ✅ pill مخصوص کارت تیره (داخل DogCard class)
Widget _pillDark({IconData? icon, required String text}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
Widget _buildMiniInfoTag({
  required IconData icon,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppTheme.primary.withOpacity(0.25),
        width: 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTheme.caption(color: AppTheme.primary),
        ),
      ],
    ),
  );
}
}