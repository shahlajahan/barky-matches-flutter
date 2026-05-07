

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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/models/media_item.dart';

enum DogCardMode {
  normal,
  playdate,
  compact,
  adoption,
  profile, // 🔥 NEW
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
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

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

  bool get isOwner => widget.dog.ownerId == widget.currentUserId;

  late AnimationController _pulseController;
Animation<double>? _pulseAnimation;

int _currentIndex = 0;
PageController _pageController = PageController();

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
  final isOwner = widget.dog.ownerId == widget.currentUserId;
final isHighlighted = widget.dog.isSponsored;
  return GestureDetector(
  onTap: widget.disableTap
    ? null
    : () {
        widget.onCardTap?.call();
      },
  child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isHighlighted ? Colors.white : Colors.white,
      borderRadius: BorderRadius.circular(16),
     boxShadow: widget.dog.isSponsored
    ? [
        BoxShadow(
          color: const Color(0xFF9E1B4F).withOpacity(0.25),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ]
    : AppTheme.cardShadow(),

border: widget.dog.isSponsored
    ? Border.all(
        color: const Color(0xFF9E1B4F),
        width: 1.5,
      )
    : null,
    ),
    child: Row(
      children: [

        // 🖼 IMAGE
       Stack(
  children: [
    SizedBox(
      width: 70,
      height: 70,
      child: _buildCompactImage(context),
    ),

    // 🔥 BOOST BADGE
    if (widget.dog.isSponsored)
      Positioned(
        top: 2,
        left: 2,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.bolt,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
  ],
),

        const SizedBox(width: 12),

        // 📄 INFO
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                widget.dog.name,
                style: AppTheme.h2(),
              ),

              const SizedBox(height: 4),

              Text(
                translateBreed(widget.dog.breed),
                style: AppTheme.caption(),
              ),

const SizedBox(height: 4),

Text(
  "distance unknown",
  style: AppTheme.caption(),
),
              const SizedBox(height: 6),

              Row(
                children: [
                  _buildTag(translateGender(widget.dog.gender)),
                  const SizedBox(width: 6),
                  _buildTag(translateHealthStatus(widget.dog.healthStatus)),
                ],
              ),
            ],
          ),
        ),

        Icon(
  Icons.chevron_right,
  color: Colors.grey.shade400,
),
      ],
    ),
  ),
  );
}

  Widget _buildCompactImage(BuildContext context) {
  final paths = widget.dog.imagePaths;

  if (paths.isEmpty) {
    return _fallbackImage();
  }

  final path = paths.first;
  final isVideo = path.toLowerCase().contains('.mp4');

  return GestureDetector(
  behavior: HitTestBehavior.opaque, // 🔥 مهم
  onTap: () {
    debugPrint("IMAGE TAP WORKED"); // تست
    _openFullScreenViewer(0);
  },
  child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [

          // 🖼 IMAGE / VIDEO PREVIEW
          AspectRatio(
            aspectRatio: 1, // 👈 همه مربع (حل deform)
            child: isVideo
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 30),
                    ),
                  )
                : Image.network(
                    path,
                    fit: BoxFit.cover, // 👈 crop تمیز
                  ),
          ),

          // 🔢 MULTI MEDIA COUNT
          if (paths.length > 1)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${paths.length - 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

          // 🎥 VIDEO ICON
          if (isVideo)
            Positioned(
              top: 4,
              left: 4,
              child: Icon(
                Icons.videocam,
                color: Colors.white,
                size: 14,
              ),
            ),
        ],
      ),
    ),
  );
}

void _showBoostSheet(BuildContext context, Dog dog) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.zap, color: Color(0xFF9E1B4F)),
                  const SizedBox(width: 8),
                  Text(
                    "Boost ${dog.name}",
                    style: AppTheme.h2(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Get more visibility in Playmates discovery.",
                style: AppTheme.body(color: AppTheme.muted),
              ),
              const SizedBox(height: 16),

              _boostOption(
                title: "24 Hours Boost",
                subtitle: "Good for quick visibility",
                price: "₺29",
                onTap: () => _boostDog(
                  dog,
                  hours: 24,
                  boostScore: 80,
                  sponsorshipType: 'boost_24h',
                ),
              ),

              _boostOption(
                title: "3 Days Boost",
                subtitle: "Better exposure for active discovery",
                price: "₺69",
                onTap: () => _boostDog(
                  dog,
                  hours: 72,
                  boostScore: 120,
                  sponsorshipType: 'boost_3d',
                ),
              ),

              _boostOption(
                title: "7 Days Boost",
                subtitle: "Best value for maximum reach",
                price: "₺129",
                onTap: () => _boostDog(
                  dog,
                  hours: 168,
                  boostScore: 180,
                  sponsorshipType: 'boost_7d',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _boostOption({
  required String title,
  required String subtitle,
  required String price,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Color(0xFF9E1B4F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                 style: AppTheme.caption().copyWith(
  color: const Color(0xFF9E1B4F).withOpacity(0.6),
),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF9E1B4F),
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _boostDog(
  Dog dog, {
  required int hours,
  required int boostScore,
  required String sponsorshipType,
}) async {
  final expiresAt = Timestamp.fromDate(
    DateTime.now().add(Duration(hours: hours)),
  );

  try {
    await FirebaseFirestore.instance
        .collection('dogs')
        .doc(dog.id)
        .update({
      'isSponsored': true,
      'boostScore': boostScore,
      'boostExpiresAt': expiresAt,
      'sponsorshipType': sponsorshipType,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Boost activated 🚀")),
    );
  } catch (e) {
    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Boost failed: $e")),
    );
  }
}

Widget _fallbackImage() {
  return Container(
    width: double.infinity,
    height: 180,
    color: const Color(0xFF9E1B4F).withOpacity(0.05),
    child: Center(
      child: Image.asset(
        'assets/image/logo.png', // 🔴 مسیر لوگوی خودت
        width: 70,
        height: 70,
        fit: BoxFit.contain,
      ),
    ),
  );
}

 Widget _buildExpandedDogImage(String imagePath) {
  final isVideo = imagePath.toLowerCase().contains('.mp4');

  // 🚨 اگر ویدیو بود → اصلاً image لود نکن
  if (isVideo) {
    return Container(
      width: double.infinity,
      height: 180,
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 50,
        ),
      ),
    );
  }

  // ✅ IMAGE (فقط اگر واقعاً عکس بود)
  if (imagePath.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: imagePath,
      width: double.infinity,
      height: 180,
      fit: BoxFit.contain,
      placeholder: (context, url) =>
          Container(color: Colors.grey.shade200),
      errorWidget: (context, url, error) {
        return _fallbackImage();
      },
    );
  }

  return Image.file(
    File(imagePath),
    width: double.infinity,
    height: 180,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => _fallbackImage(),
  );
}
  @override
void initState() {
  super.initState();

  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  _pulseAnimation = Tween<double>(
    begin: 0.2,
    end: 0.5,
  ).animate(
    CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ),
  );

  if (widget.dog.isSponsored) {
    _pulseController.repeat(reverse: true);
  }
}

@override
void dispose() {
  _pulseController.dispose();
  super.dispose();
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
print("🐶 dog owner: ${widget.dog.ownerId}");
print("👤 current user: ${widget.currentUserId}");
  return RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(AppTheme.radiusCard),

  // 🔥 GLOW
  boxShadow: widget.dog.isSponsored
      ? [
          BoxShadow(
            color: const Color(0xFF9E1B4F).withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ]
      : AppTheme.cardShadow(),

  // 🟣 BORDER
  border: widget.dog.isSponsored
      ? Border.all(
          color: const Color(0xFF9E1B4F),
          width: 1.2,
        )
      : null,
),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===============================
            // 🖼 IMAGE (OPTIMIZED)
            // ===============================
          Stack(
  children: [
    AspectRatio(
  aspectRatio: 1, // 👈 مربع (بهترین برای سگ)
  child: _buildImageWrapper(imagePath),
),

    // 🔥 Boosted badge
    if (widget.dog.isSponsored)
      Positioned(
        top: 10,
        left: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.zap, size: 14, color: Colors.black),
              SizedBox(width: 4),
              Text(
                "BOOSTED",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),

    // 🚀 Boost button فقط برای صاحب سگ
    if (widget.dog.ownerId == widget.currentUserId)
      Positioned(
        top: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showBoostSheet(context, widget.dog),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.zap, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Boost",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
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
  style: AppTheme.h1().copyWith(
    color: const Color(0xFF9E1B4F),
  ),
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
if (widget.mode == DogCardMode.profile) {
  return _buildProfileDogCard(context);
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
              AspectRatio(
  aspectRatio: 1, // 👈 مربع (بهترین برای سگ)
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
    style: AppTheme.h1().copyWith(
      color: const Color(0xFF9E1B4F),
    ),
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
  style: AppTheme.caption(
    color: const Color(0xFF9E1B4F).withOpacity(0.6),
  ),
),
  ],
),
                    const SizedBox(height: 6),

                    Text(
  translateBreed(widget.dog.breed),
  style: AppTheme.body(
    color: const Color(0xFF9E1B4F).withOpacity(0.7),
  ),
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
                          icon: LucideIcons.dog,
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

Widget _buildProfileDogCard(BuildContext context) {
  final imagePath =
      widget.dog.imagePaths.isNotEmpty ? widget.dog.imagePaths.first : null;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
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

            // 🖼 IMAGE + BOOST
            Stack(
              children: [
                AspectRatio(
  aspectRatio: 1,
  child: PageView.builder(   // ✅ درست
    controller: _pageController,
    itemCount: widget.dog.imagePaths.length,
    onPageChanged: (index) {
      setState(() {
        _currentIndex = index;
      });
    },
    itemBuilder: (context, index) {
  final path = widget.dog.imagePaths[index];
  final isVideo = path.toLowerCase().contains('.mp4');

return GestureDetector(
  onTap: () => _openFullScreenViewer(index),
  child: Stack(
    alignment: Alignment.center,
    children: [

      // 👇 مهم‌ترین بخش
      if (!isVideo)
        _buildImageWrapper(path)
      else
        Container(
          color: Colors.black,
        ),

      if (isVideo)
        const Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 40,
        ),
    ],
  ),
);
},
),
),

// 🌙 BOTTOM GRADIENT برای اینکه dots و swipe hint دیده بشه
if (widget.dog.imagePaths.length > 1)
  Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    height: 46,
    child: IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.35),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  ),

// 🔥 DOT INDICATOR 👇 اینجااااا
    if (widget.dog.imagePaths.length > 1)
      Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.dog.imagePaths.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == index ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? Colors.white
                    : Colors.white54,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),

      // 🔢 MEDIA COUNT مثل 1/3
if (widget.dog.imagePaths.length > 1)
  Positioned(
    top: 12,
    right: 12,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '${_currentIndex + 1}/${widget.dog.imagePaths.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),
                // 🔥 BOOST BUTTON
                Positioned(
                  top: 46,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _showBoostSheet(context, widget.dog),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E1B4F),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.zap, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Boost",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                

                // ✏️ EDIT
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () => _openEditDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFF9E1B4F),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 📄 INFO
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
  widget.dog.name,
  style: AppTheme.h1().copyWith(
    color: const Color(0xFF9E1B4F),
  ),
),
                  const SizedBox(height: 4),

                  Text(
                    '${widget.dog.age}y • ${translateBreed(widget.dog.breed)}',
                    style: AppTheme.body(color: AppTheme.muted),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTag(translateGender(widget.dog.gender)),
                      _buildTag(translateHealthStatus(widget.dog.healthStatus)),
                    ],
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
List<MediaItem> _buildMediaItems() {
  return widget.dog.imagePaths.map((path) {
    final isVideo = path.toLowerCase().contains('.mp4');

    return MediaItem(
      url: path,
      type: isVideo ? MediaType.video : MediaType.image,
    );
  }).toList();
}


void _openFullScreenViewer(int initialIndex) {
  final items = _buildMediaItems();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GalleryViewerPage(
        items: items,
        initialIndex: initialIndex,
      ),
    ),
  );
}

Widget _buildUnifiedTag({
  required String text,
  IconData? icon,
  Color? color,
}) {
  final tagColor = color ?? AppTheme.primary;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tagColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: tagColor),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: AppTheme.caption().copyWith(
            color: tagColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTag(
  String text, {
  Color? color,
}) {
  final tagColor = color ?? AppTheme.primary;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tagColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: AppTheme.caption().copyWith(
        color: tagColor,
        fontWeight: FontWeight.w600,
      ),
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
  child: Stack(
    children: [
      Positioned.fill(
        child: imagePath != null
            ? _buildExpandedDogImage(imagePath)
            : Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.pets,
                  size: 48,
                  color: Colors.white70,
                ),
              ),
      ),
      if (widget.dog.isSponsored)
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zap, size: 12, color: Colors.black),
                SizedBox(width: 4),
                Text(
                  "BOOSTED",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
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
                      _pillDark(icon: LucideIcons.dog, text: translateGender(widget.dog.gender)),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF9E1B4F).withOpacity(0.12),
          const Color(0xFF9E1B4F).withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: const Color(0xFF9E1B4F),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTheme.caption().copyWith(
  color: const Color(0xFF9E1B4F).withOpacity(0.6),
),
        ),
      ],
    ),
  );
}
}

class _OtherUserDogCard extends StatefulWidget {
  final Dog dog;

  const _OtherUserDogCard({required this.dog});

  @override
  State<_OtherUserDogCard> createState() => _OtherUserDogCardState();
}

class _OtherUserDogCardState extends State<_OtherUserDogCard> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final paths = widget.dog.imagePaths;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 🔥 MEDIA SLIDER
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [

                  PageView.builder(
                    controller: _controller,
                    itemCount: paths.length,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                    },
                    itemBuilder: (_, i) {
                      final path = paths[i];
                      final isVideo =
                          path.toLowerCase().contains('.mp4');

                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: isVideo
                              ? const Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 50)
                              : Image.network(
                                  path,
                                  fit: BoxFit.contain, // 👈 FIX deform
                                ),
                        ),
                      );
                    },
                  ),

                  // 🔢 counter
                  if (paths.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_index + 1}/${paths.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),

                  // 🔘 dots
                  if (paths.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: List.generate(
                          paths.length,
                          (i) => Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: _index == i ? 10 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 🐶 INFO
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.dog.name,
                    style: AppTheme.h2()),
                const SizedBox(height: 4),
                Text(widget.dog.breed ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}