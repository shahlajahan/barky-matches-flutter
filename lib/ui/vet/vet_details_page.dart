import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../theme/app_theme.dart';
import '../business/business_card_data.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../common/gallery_viewer_page.dart';
import '../../models/media_item.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';

enum ReviewSortType { mostRelevant, newest }

class VetDetailsPage extends StatefulWidget {
  final BusinessCardData vet;
  final VoidCallback? onClose;

  const VetDetailsPage({super.key, required this.vet, this.onClose});

  @override
  State<VetDetailsPage> createState() => _VetDetailsPageState();
}

class _VetDetailsPageState extends State<VetDetailsPage>
    with SingleTickerProviderStateMixin {
  bool get _hasShop => false;
  int get _tabCount => _hasShop ? 5 : 4;
  late final TabController _tabController;
  ReviewSortType _sortType = ReviewSortType.mostRelevant;
  // 🔥 LIKE STATE (IMPORTANT)
  final Map<String, int> _optimisticLikes = {};
  final Map<String, bool> _optimisticIsLiked = {};
  final Set<String> _likeBusy = {};
  double? _liveRating;
  int _liveReviewCount = 0;

  Map<String, dynamic>? get _workingHoursMap {
    final raw = widget.vet.workingHours;

    if (raw == null) return null;

    // حالت استاندارد
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    // حالت dynamic map (Firestore)
    if (raw is Map<dynamic, dynamic>) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    // حالت string (fallback)
    if (raw is String) {
      return {'hours': raw};
    }

    return null;
  }

  String get _locationText {
    final vet = widget.vet;
    return '${vet.district ?? ''}${(vet.district != null && vet.city != null) ? ', ' : ''}${vet.city ?? ''}';
  }

  String _todayHoursText() {
    final l10n = AppLocalizations.of(context)!;
    final hours = _workingHoursMap;
    if (hours == null || hours.isEmpty) return l10n.workingHoursNotAvailable;

    final weekday = DateTime.now().weekday;
    const keys = {
      1: ['monday', 'mon'],
      2: ['tuesday', 'tue'],
      3: ['wednesday', 'wed'],
      4: ['thursday', 'thu'],
      5: ['friday', 'fri'],
      6: ['saturday', 'sat'],
      7: ['sunday', 'sun'],
    };

    final todayKeys = keys[weekday]!;
    dynamic value;

    for (final key in todayKeys) {
      if (hours.containsKey(key)) {
        value = hours[key];
        break;
      }
      final capitalized = key[0].toUpperCase() + key.substring(1);
      if (hours.containsKey(capitalized)) {
        value = hours[capitalized];
        break;
      }
    }

    if (value == null) {
      if (hours.containsKey('hours')) {
        value = hours['hours'];
      }
    }

    if (value == null) return l10n.workingHoursNotAvailable;
    return value.toString();
  }

  String _openingStatusLabel() {
    final l10n = AppLocalizations.of(context)!;
    final text = _todayHoursText();

    if (text == l10n.workingHoursNotAvailable) return text;

    final normalized = text.replaceAll(' ', '');
    if (!normalized.contains('-')) return text;

    final parts = normalized.split('-');
    if (parts.length != 2) return text;

    TimeOfDay? parsePart(String input) {
      final p = input.split(':');
      if (p.length != 2) return null;

      int? hour = int.tryParse(p[0]);
      int? minute = int.tryParse(p[1]);

      if (hour == null || minute == null) return null;

      // 🔥 FIX 24:00 → 00:00 next day
      if (hour == 24 && minute == 0) {
        hour = 0;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

      return TimeOfDay(hour: hour, minute: minute);
    }

    final open = parsePart(parts[0]);
    final close = parsePart(parts[1]);

    if (open == null || close == null) return text;

    final now = TimeOfDay.now();

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    int adjustedCloseMinutes = closeMinutes;

    // 🔥 اگر 00:00 یا 24:00 بود یعنی پایان روز
    if (parts[1] == '00:00' || parts[1] == '24:00') {
      adjustedCloseMinutes = 24 * 60;
    }

    // 🔥 overnight case (مثلا 18:00 → 03:00)
    if (adjustedCloseMinutes < openMinutes) {
      final isOpen =
          nowMinutes >= openMinutes || nowMinutes <= adjustedCloseMinutes;

      if (!isOpen) return l10n.openStatusClosed;

      // closing soon (overnight)
      int minutesToClose;
      if (nowMinutes >= openMinutes) {
        minutesToClose = (24 * 60 - nowMinutes) + adjustedCloseMinutes;
      } else {
        minutesToClose = adjustedCloseMinutes - nowMinutes;
      }

      if (minutesToClose <= 60) return l10n.openStatusClosingSoon;

      return l10n.openStatusOpen;
    }

    // 🔥 normal case
    if (nowMinutes < openMinutes || nowMinutes > adjustedCloseMinutes) {
      return l10n.openStatusClosed;
    }

    if (adjustedCloseMinutes - nowMinutes <= 60) {
      return l10n.openStatusClosingSoon;
    }

    return l10n.openStatusOpen;
  }

  Stream<QuerySnapshot> _getReviewsStream() {
    final collection = FirebaseFirestore.instance
        .collection('reviews')
        .where('vetId', isEqualTo: widget.vet.id);

    if (_sortType == ReviewSortType.newest) {
      return collection.orderBy('createdAt', descending: true).snapshots();
    } else {
      return collection.orderBy('rankScore', descending: true).snapshots();
    }
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabCount, vsync: this);

    debugPrint("🔥 VET ID = ${widget.vet.id}");

    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleClose() {
    FocusManager.instance.primaryFocus?.unfocus();

    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }

    context.read<AppState>().closeVetDetails();
  }

  void _openAppointmentPage([Map<String, dynamic>? service]) {
    debugPrint("🔥 OPEN APPOINTMENT WITH: $service");

    FocusManager.instance.primaryFocus?.unfocus();

    final appState = context.read<AppState>();
    final onClose = widget.onClose;

    if (onClose != null) {
      onClose();
    } else {
      appState.closeVetDetails();
    }

    appState.openBusinessAppointment(widget.vet, selectedService: service);
  }

  Future<void> _openWriteReviewSheet({
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
  }) async {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      builder: (_) => _WriteReviewSheet(vetId: widget.vet.id),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Future<void> _openGalleryViewer(
    List<MediaItem> items,
    int initialIndex,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.of(sheetContext).size.height;
        return SizedBox(
          height: height * 0.95,
          child: GalleryViewerPage(items: items, initialIndex: initialIndex),
        );
      },
    );
  }

  Widget _buildSortToggle() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSortItem(
            title: l10n.mostRelevant,
            type: ReviewSortType.mostRelevant,
          ),
          _buildSortItem(title: l10n.newest, type: ReviewSortType.newest),
        ],
      ),
    );
  }

  Widget _buildSortItem({required String title, required ReviewSortType type}) {
    final isSelected = _sortType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _sortType = type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _handleClose,
            child: Container(color: Colors.black54),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.92,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            _buildHeader(),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _handleClose,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTabs(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(),
                              _buildServicesTab(),
                              _buildReviewsTab(),
                              _buildGalleryTab(),
                              if (_hasShop) _buildShopTab(),
                            ],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: SizedBox(
                              height: 54,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
  final businessData = widget.vet.rawData ?? {};

  final vetData =
      (businessData['sectorData']?['veterinary']
          as Map<String, dynamic>?) ??
      {};

  final servicesData =
      (vetData['services']
          as Map<String, dynamic>?) ??
      {};
      debugPrint("🧪 FULL VET DATA = $vetData");
debugPrint("🧪 SERVICES DATA = $servicesData");
debugPrint("🧪 SERVICES DATA = $servicesData");
  final services = servicesData.entries
    .where((e) => e.value is Map)
    .map((e) {
      final map = Map<String, dynamic>.from(e.value);

      return {
        'id': e.key,
        'title': map['title'] ?? e.key,
        'price': map['price'],
        'duration': map['duration'],
      };
    })
    .toList();

if (services.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.noServicesAvailable),
      ),
    );
    return;
  }

  _openAppointmentPage({
    ...services.first,
  });
},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  l10n.bookAppointment,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> data, {Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;
    final String reviewId = data['id'] as String;

    final List likedBy = List.from(data['likedBy'] ?? []);
    final bool firestoreIsLiked =
        currentUser != null && likedBy.contains(currentUser.uid);
    final int firestoreLikesCount = (data['likes'] ?? 0) as int;
    final reviewsCount = data['reviewerStats']?['reviewsCount'] ?? 0;

    final isTopReviewer = reviewsCount >= 5;
    final totalLikes = data['reviewerStats']?['totalLikes'] ?? 0;

    final trustScore = data['reviewerStats']?['trustScore'] ?? 0;
    final bool isLiked = _optimisticIsLiked[reviewId] ?? firestoreIsLiked;
    final int likesCount = _optimisticLikes[reviewId] ?? firestoreLikesCount;
    final bool isBusy = _likeBusy.contains(reviewId);
    final isVerified = data['reviewerStats']?['isVerified'] == true;
    final userName = data['userName'] ?? l10n.unknownUser;
    final userPhoto = data['userPhoto'];
    final userId = data['userId'];
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (data['rankScore'] ?? 0) > 80
              ? Colors.green
              : Colors.grey.shade200,
          width: (data['rankScore'] ?? 0) > 80 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, snapshot) {
                  String? photoUrl = userPhoto;

                  // 🔥 fallback از users collection
                  if ((photoUrl == null || photoUrl.isEmpty) &&
                      snapshot.hasData) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    photoUrl = userData?['photoUrl'];
                  }

                  // 🔥 اگر هنوز null بود → fallback به FirebaseAuth
                  if ((photoUrl == null || photoUrl.isEmpty) &&
                      FirebaseAuth.instance.currentUser?.uid == userId) {
                    photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
                  }

                  final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: hasPhoto
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                userName[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            userName[0].toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['userName'] ?? l10n.unknownUser,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        // 🔵 Verified
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ],

                        // 🟣 Top Reviewer
                        if (reviewsCount >= 10) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.topLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (likesCount >= 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.mostHelpful,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    Text(
                      _timeAgo(data['createdAt'] as Timestamp?),
                      style: AppTheme.caption(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStars((data['rating'] ?? 0).toDouble(), size: 16),
          const SizedBox(height: 8),
          Text(data['text'] ?? '', style: AppTheme.bodyMedium()),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        debugPrint("👍 LIKE TAPPED");

                        if (currentUser == null) return;

                        final docRef = FirebaseFirestore.instance
                            .collection('reviews')
                            .doc(reviewId);

                        final bool nextIsLiked = !isLiked;
                        final int nextLikes = nextIsLiked
                            ? likesCount + 1
                            : likesCount - 1;

                        setState(() {
                          _likeBusy.add(reviewId);
                          _optimisticIsLiked[reviewId] = nextIsLiked;
                          _optimisticLikes[reviewId] = nextLikes < 0
                              ? 0
                              : nextLikes;
                        });

                        try {
                          if (isLiked) {
                            // 👎 UNLIKE
                            await docRef.update({
                              'likes': FieldValue.increment(-1),
                              'likedBy': FieldValue.arrayRemove([
                                currentUser.uid,
                              ]),
                            });
                          } else {
                            // 👍 LIKE
                            await docRef.update({
                              'likes': FieldValue.increment(1),
                              'likedBy': FieldValue.arrayUnion([
                                currentUser.uid,
                              ]),
                            });
                          }

                          if (!mounted) return;

                          setState(() {
                            _likeBusy.remove(reviewId);
                          });
                        } catch (e) {
                          debugPrint("🔥 LIKE ERROR: $e");

                          if (!mounted) return;

                          setState(() {
                            _likeBusy.remove(reviewId);
                            _optimisticIsLiked.remove(reviewId);
                            _optimisticLikes.remove(reviewId);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.couldNotUpdateLike)),
                          );
                        }
                      },
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: isLiked ? AppTheme.primary : Colors.grey,
                ),
              ),
              Text('$likesCount', style: AppTheme.caption()),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(Timestamp? timestamp) {
    final l10n = AppLocalizations.of(context)!;
    if (timestamp == null) return '';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _emptyReviewsState() {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: l10n.reviewsTitle,
          child: Column(
            children: [
              Text(l10n.noReviewsYet, style: AppTheme.bodyMedium()),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => _openWriteReviewSheet(
                  isDismissible: false,
                  enableDrag: false,
                  backgroundColor: Colors.white,
                ),
                child: Text(l10n.beFirstToReview),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final vet = widget.vet;
    final status = _openingStatusLabel();

    final fallbackImageUrl = (vet.logoUrl != null && vet.logoUrl!.isNotEmpty)
        ? vet.logoUrl!
        : '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(vet.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final rawProfile =
    data['sectorData']?['veterinary']?['profileContent'];
        final liveProfile = rawProfile is Map
            ? Map<String, dynamic>.from(rawProfile)
            : <String, dynamic>{};
        final liveImages = data['images'] is List
            ? List<String>.from(data['images'])
            : <String>[];
        final imageUrl =
            [
                  data['coverImageUrl'],
                  liveProfile['coverImageUrl'],
                  liveProfile['coverUrl'],
                  if (liveImages.isNotEmpty) liveImages.first,
                  fallbackImageUrl,
                ]
                .map((value) => value?.toString().trim() ?? '')
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');

        return Stack(
          children: [
            // 🖼️ COVER IMAGE
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          LucideIcons.stethoscope,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        LucideIcons.stethoscope,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),

            // 🌫️ GRADIENT OVERLAY
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),

            // 📌 INFO ON IMAGE
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vet.name,
                    style: AppTheme.h1().copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _locationText,
                    style: AppTheme.bodyMedium(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),

                  // ⭐ Rating
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (_liveRating ?? vet.rating)?.toStringAsFixed(1) ?? '-',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${l10n.reviewsCountLabel(_liveReviewCount != 0 ? _liveReviewCount : (vet.reviewsCount ?? 0))})',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 🟢 OPEN STATUS
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status == l10n.openStatusOpen
                          ? const Color(0xFF4CAF50)
                          : status == l10n.openStatusClosingSoon
                          ? const Color(0xFFFF9800)
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status == l10n.workingHoursNotAvailable
                          ? status
                          : '$status • ${_todayHoursText()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primary,
        unselectedLabelColor: Colors.black54,
        indicatorColor: const Color(0xFFFFC107),
        tabs: [
          Tab(text: l10n.overviewTitle),
          Tab(text: l10n.servicesTitle),
          Tab(text: l10n.reviewsTitle),
          Tab(text: l10n.galleryTitle),
          if (_hasShop) Tab(text: l10n.shopTitle),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context)!;
    final vet = widget.vet;
    final businessData = widget.vet.rawData ?? {};

final vetData =
    (businessData['sectorData']?['veterinary']
        as Map<String, dynamic>?) ??
    {};

final profileContent =
    (vetData['profileContent']
        as Map<String, dynamic>?) ??
    {};

final bio =
    (profileContent['bio'] ?? '').toString().trim();

final about = bio.isNotEmpty
    ? bio
    : l10n.noClinicDescriptionAvailable;

    final socialMedia =
    (profileContent['socialMedia']
        as Map<String, dynamic>?) ??
    {};

final instagram =
    (socialMedia['instagram'] ?? '')
        .toString()
        .trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: l10n.aboutTitle,
          child: Text(
            about,
            style: AppTheme.bodyMedium(
              color: Colors.black87,
            ).copyWith(height: 1.55),
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: l10n.workingHoursTitle,
          child: _buildWorkingHoursSection(),
        ),
        const SizedBox(height: 14),
        _sectionCard(
  title: l10n.instagramTitle,
  child: Text(
    instagram.isNotEmpty
        ? instagram
        : l10n.instagramNotAvailable,
    style: AppTheme.bodyMedium(
      color: Colors.black87,
    ),
  ),
),


        const SizedBox(height: 14),
        _sectionCard(
          title: l10n.locationTitle,
          child: Text(
            _locationText,
            style: AppTheme.bodyMedium(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesTab() {
  final l10n = AppLocalizations.of(context)!;

  final businessData = widget.vet.rawData ?? {};

  final vetData =
      (businessData['sectorData']?['veterinary']
          as Map<String, dynamic>?) ??
      {};

  final servicesData =
      (vetData['services']
          as Map<String, dynamic>?) ??
      {};

  debugPrint("🧪 SERVICES DATA = $servicesData");

  final List<Map<String, dynamic>> services = [];

  // 🔥 OLD STRUCTURE
  if (servicesData['offeredServices'] is List) {
    final offered = List<String>.from(
      servicesData['offeredServices'],
    );

    services.addAll(
      offered.map(
        (e) => {
          'title': e,
        },
      ),
    );
  }

  // 🔥 NEW STRUCTURE
  else {
    services.addAll(
      servicesData.entries
          .where((e) => e.value is Map)
          .map((e) {
            final map = Map<String, dynamic>.from(e.value);

            return {
              'id': e.key,
              'title': map['title'] ?? e.key,
              'price': map['price'],
              'duration': map['duration'],
            };
          })
          .toList(),
    );
  }

  debugPrint("📦 SERVICES COUNT: ${services.length}");

  if (services.isEmpty) {
    return Center(
      child: Text(
        l10n.noServicesProvided,
        style: AppTheme.caption(color: Colors.black54),
      ),
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: services.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, index) {
      final service = services[index];

      final title =
          (service['title'] ?? '').toString();

      final price = service['price'];
      final duration = service['duration'];

      return GestureDetector(
        onTap: () {
          debugPrint("🔥 OPEN APPOINTMENT WITH: $service");

          _openAppointmentPage(service);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.check,
                color: Colors.amber,
                size: 18,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium(),
                    ),

                    if (price != null ||
                        duration != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        [
                          if (price != null)
                            '₺$price',

                          if (duration != null)
                            duration.toString(),
                        ].join(' • '),
                        style: AppTheme.caption(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.bodyMedium().copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildWorkingHoursSection() {
    final l10n = AppLocalizations.of(context)!;
    final hours = _workingHoursMap;

    if (hours == null || hours.isEmpty) {
      return Text(
        l10n.workingHoursNotAvailable,
        style: AppTheme.bodyMedium(color: Colors.black87),
      );
    }

    final entries = hours.entries.toList();

    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.key.toString(),
                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  entry.value.toString(),
                  textAlign: TextAlign.right,
                  style: AppTheme.bodyMedium(color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewsTab() {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: _getReviewsStream(),

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("🔥 FIRESTORE ERROR: ${snapshot.error}");
          return Center(
            child: Text(l10n.errorLoadingReviews(snapshot.error.toString())),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyReviewsState();
        }

        final reviews = snapshot.data!.docs;

        // ⭐ average
        double avg = 0;
        for (var doc in reviews) {
          avg += (doc['rating'] ?? 0).toDouble();
        }
        avg = avg / reviews.length;

        // 🔥 update header realtime
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              (_liveRating != avg || _liveReviewCount != reviews.length)) {
            setState(() {
              _liveRating = avg;
              _liveReviewCount = reviews.length;
            });
          }
        });

        // ⭐ rating breakdown
        Map<String, int> ratingCounts = {
          "1": 0,
          "2": 0,
          "3": 0,
          "4": 0,
          "5": 0,
        };

        for (var doc in reviews) {
          final r = (doc['rating'] ?? 0).toInt().toString();
          if (ratingCounts.containsKey(r)) {
            ratingCounts[r] = ratingCounts[r]! + 1;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSortToggle(), // 👈 اضافه کن
            _buildRatingHeader(avg, reviews.length, ratingCounts),
            const SizedBox(height: 16),

            ...reviews.map((doc) {
              final data = Map<String, dynamic>.from(
                doc.data() as Map<String, dynamic>,
              );
              data['id'] = doc.id;

              return _buildReviewItem(data, key: ValueKey(doc.id));
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildRatingHeader(
    double avg,
    int count,
    Map<String, dynamic> ratingCounts,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return _sectionCard(
      title: l10n.reviewsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐ عدد + ستاره
          Row(
            children: [
              Text(avg.toStringAsFixed(1), style: AppTheme.h1()),
              const SizedBox(width: 8),
              _buildStars(avg),
            ],
          ),

          const SizedBox(height: 6),

          Text(l10n.reviewsCountLabel(count)),

          const SizedBox(height: 12),

          // 📊 breakdown
          ...List.generate(5, (i) {
            int star = 5 - i;
            int value = ratingCounts["$star"] ?? 0;

            double percent = count == 0 ? 0 : value / count;

            return Row(
              children: [
                Text("$star"),
                const SizedBox(width: 6),

                const Icon(Icons.star, size: 14, color: Colors.amber),

                const SizedBox(width: 8),

                Expanded(
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),

                const SizedBox(width: 8),

                Text("$value"),
              ],
            );
          }),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _openWriteReviewSheet,
            icon: const Icon(Icons.edit),
            label: Text(l10n.writeAReview),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    return Row(
      children: List.generate(5, (index) {
        if (rating >= index + 1) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (rating >= index + 0.25 && rating < index + 0.75) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Future<void> fixOldReviews() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data['rankScore'] != null && data['rankScore'] != 0) {
        continue; // ⛔ قبلاً fix شده
      }

      final likes = data['likes'] ?? 0;
      final rating = (data['rating'] ?? 0).toDouble();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      final ageHours = DateTime.now()
          .difference(createdAt ?? DateTime.now())
          .inHours;

      final freshness = 1 / (1 + ageHours);

      final rankScore = (likes * 3) + (rating * 2) + freshness;

      await doc.reference.update({'rankScore': rankScore});
    }

    debugPrint("🔥 FIX DONE ONCE");
  }

  Widget _buildGalleryTab() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.vet.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Text(
              l10n.galleryNotAvailable,
              style: AppTheme.caption(color: Colors.black54),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        // 🔥 مهم: هم images هم videos
        final rawProfileContent =
    data['sectorData']?['veterinary']?['profileContent'];

final profileContent =
    rawProfileContent is Map
        ? Map<String, dynamic>.from(rawProfileContent)
        : <String, dynamic>{};

final images = List<String>.from(
  profileContent['clinicPhotoUrls'] ?? [],
);

final videos = List<String>.from(
  profileContent['clinicVideoUrls'] ?? [],
);

        final gallery = [
          ...images.map((e) => MediaItem.fromUrl(e)),
          ...videos.map((e) => MediaItem.fromUrl(e)),
        ];

        if (gallery.isEmpty) {
          return Center(
            child: Text(
              l10n.noGalleryMediaYet,
              style: AppTheme.caption(color: Colors.black54),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: gallery.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final item = gallery[index];
            final isVideo = item.type == MediaType.video;

            return GestureDetector(
              onTap: () => _openGalleryViewer(gallery, index),
              child: Hero(
                tag: item.url,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ✅ فقط عکس‌ها Image.network
                      SmartMedia(url: item.url, fit: BoxFit.cover),

                      // 🎥 overlay
                      if (isVideo) Container(color: Colors.black26),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShopTab() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.shopSectionComingSoon,
        style: AppTheme.caption(color: Colors.black54),
      ),
    );
  }
}

class _WriteReviewSheet extends StatefulWidget {
  final String vetId;

  const _WriteReviewSheet({required this.vetId});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final TextEditingController _reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();

  double _reviewRating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewFocusNode.unfocus();
    _reviewFocusNode.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isSubmitting = true);
    var shouldResetSubmitting = true;

    try {
      final l10n = AppLocalizations.of(context)!;
      final text = _reviewController.text.trim();

      if (text.isEmpty) {
        _showSnack(l10n.pleaseWriteSomething);
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showSnack(l10n.pleaseLoginFirst);
        return;
      }

      final vetId = widget.vetId;

      final existing = await FirebaseFirestore.instance
          .collection('reviews')
          .where('vetId', isEqualTo: vetId)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (!mounted) return;

      if (existing.docs.isNotEmpty) {
        _showSnack(l10n.alreadyReviewedThisVet);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data() ?? {};
      final userName = userData['username'] ?? l10n.unknownUser;
      final userPhoto = userData['photoUrl'] ?? currentUser.photoURL;
      debugPrint("PHOTO URL: $userPhoto");

      final userReviews = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (!mounted) return;

      await FirebaseFirestore.instance.collection('reviews').add({
        'vetId': vetId,
        'userId': currentUser.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'rating': _reviewRating,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'rankScore': 0,
        'reviewerStats': {
          'reviewsCount': userReviews.docs.length,
          'totalLikes': 0,
          'trustScore': 0,
          'isVerified': currentUser.emailVerified,
          'badges': [],
        },
        'rankingMeta': {
          'textLengthBonus': 0,
          'helpfulScore': 0,
          'credibilityScore': 0,
          'freshnessScore': 0,
          'spamPenalty': 0,
          'lastRankedAt': null,
        },
      });

      if (!mounted) return;

      shouldResetSubmitting = false;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("🔥 ERROR: $e");

      if (!mounted) return;
      _showSnack(AppLocalizations.of(context)!.errorSubmittingReview);
    } finally {
      if (shouldResetSubmitting && mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.writeAReview, style: AppTheme.h2()),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _reviewRating = index + 1.0;
                                });
                              },
                        icon: Icon(
                          Icons.star,
                          size: 30,
                          color: index < _reviewRating
                              ? Colors.amber
                              : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reviewController,
                    focusNode: _reviewFocusNode,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.shareYourExperienceHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.submit,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
