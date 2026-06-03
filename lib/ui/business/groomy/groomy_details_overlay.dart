import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

enum ReviewSortType { mostRelevant, newest }

class GroomyDetailsOverlay extends StatefulWidget {
  final BusinessCardData data;
  final VoidCallback onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onDirections;
  final ValueChanged<Map<String, dynamic>>? onOpenAppointment;

  const GroomyDetailsOverlay({
    super.key,
    required this.data,
    required this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onDirections,
    this.onOpenAppointment,
  });

  @override
  State<GroomyDetailsOverlay> createState() => _GroomyDetailsOverlayState();
}

class _GroomyDetailsOverlayState extends State<GroomyDetailsOverlay>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ReviewSortType _sortType = ReviewSortType.mostRelevant;

  final Map<String, int> _optimisticLikes = {};
  final Map<String, bool> _optimisticIsLiked = {};
  final Set<String> _likeBusy = {};

  final ValueNotifier<double?> _liveRating = ValueNotifier<double?>(null);
  final ValueNotifier<int> _liveReviewCount = ValueNotifier<int>(0);

  Map<String, dynamic> get _groomyData {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    return Map<String, dynamic>.from(
      sectorData['groomy'] ??
          sectorData['groomer'] ??
          sectorData['grooming'] ??
          {},
    );
  }

  Map<String, dynamic>? get _workingHoursMap {
    final raw =
        _groomyData['workingHoursMap'] ??
        _groomyData['workingHours'] ??
        widget.data.workingHours ??
        (widget.data.rawData ?? {})['workingHoursMap'];

    if (raw == null) return null;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) return {'hours': raw};

    return null;
  }

  String get _locationText {
    final parts = <String>[
      widget.data.district.trim(),
      widget.data.city.trim(),
    ].where((item) => item.isNotEmpty).toList();
    return parts.join(', ');
  }

  String? get _heroImageUrl {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final profileContent = Map<String, dynamic>.from(
      _groomyData['profileContent'] ?? _groomyData['profile'] ?? {},
    );

    final candidates = <String>[
      ..._stringList(_groomyData['coverImageUrl']),
      ..._stringList(_groomyData['coverImage']),
      ..._stringList(profileContent['coverImageUrl']),
      ..._stringList(profileContent['coverImage']),
      ..._stringList(rawData['coverImageUrl']),
      ..._stringList(rawData['coverImage']),
      ..._stringList(rawData['images']),
      ..._stringList(rawData['clinicPhotoUrls']),
      ..._stringList(widget.data.logoUrl),
    ];

    for (final value in candidates) {
      final url = value.trim();
      if (url.isNotEmpty) return url;
    }

    return null;
  }

  List<Map<String, dynamic>> _fallbackServices() {
    final servicesData = _groomyData['services'];
    List<String> titles = [];

    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    } else if (widget.data.services != null) {
      titles = widget.data.services!;
    }

    return titles
        .where((title) => title.trim().isNotEmpty)
        .map(
          (title) => {
            'id': title.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
            'title': title,
            'price': null,
            'durationMin': 60,
          },
        )
        .toList();
  }

  double _servicePrice(Map<String, dynamic> service) {
    final raw = service['price'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _serviceDuration(Map<String, dynamic> service) {
    final raw = service['durationMin'] ?? service['duration'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 60;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getReviewsStream() {
    final collection = FirebaseFirestore.instance
        .collection('reviews')
        .where('businessId', isEqualTo: widget.data.id)
        .where('businessType', isEqualTo: 'groomy');

    if (_sortType == ReviewSortType.newest) {
      return collection.orderBy('createdAt', descending: true).snapshots();
    }

    return collection.orderBy('rankScore', descending: true).snapshots();
  }

  String _todayHoursText() {
    final l10n = AppLocalizations.of(context)!;
    final hours = _workingHoursMap;

    if (hours == null || hours.isEmpty) {
      return l10n.workingHoursNotAvailable;
    }

    final weekday = DateTime.now().weekday;
    const keys = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };

    final key = keys[weekday];
    if (key == null) return l10n.workingHoursNotAvailable;

    final raw = hours[key];
    if (raw is Map<String, dynamic>) {
      final isOpen = raw['open'] == true;
      if (!isOpen) return 'Closed';
      return (raw['hours'] ?? '09:00 - 18:00').toString();
    }

    if (raw is String) return raw;

    return l10n.workingHoursNotAvailable;
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
    if (parts[1] == '00:00' || parts[1] == '24:00') {
      adjustedCloseMinutes = 24 * 60;
    }

    if (adjustedCloseMinutes < openMinutes) {
      final isOpen =
          nowMinutes >= openMinutes || nowMinutes <= adjustedCloseMinutes;
      if (!isOpen) return l10n.openStatusClosed;

      int minutesToClose;
      if (nowMinutes >= openMinutes) {
        minutesToClose = (24 * 60 - nowMinutes) + adjustedCloseMinutes;
      } else {
        minutesToClose = adjustedCloseMinutes - nowMinutes;
      }

      if (minutesToClose <= 60) return l10n.openStatusClosingSoon;
      return l10n.openStatusOpen;
    }

    if (nowMinutes < openMinutes || nowMinutes > adjustedCloseMinutes) {
      return l10n.openStatusClosed;
    }

    if (adjustedCloseMinutes - nowMinutes <= 60) {
      return l10n.openStatusClosingSoon;
    }

    return l10n.openStatusOpen;
  }

  String _formatRating(double? rating) {
    if (rating == null || rating <= 0) return '-';
    return rating.toStringAsFixed(1);
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _liveRating.value = widget.data.rating;
    _liveReviewCount.value = widget.data.reviewsCount ?? 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveRating.dispose();
    _liveReviewCount.dispose();
    super.dispose();
  }

  void _handleClose() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onClose();
  }

  Future<void> _openGalleryViewer(
    List<MediaItem> items,
    int initialIndex,
  ) async {
    await showModalBottomSheet<void>(
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
      builder: (_) => _WriteReviewSheet(groomyId: widget.data.id),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _openAppointmentPage(Map<String, dynamic> service) {
    widget.onOpenAppointment?.call(service);
  }

  Future<void> _openFirstAvailableService() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.data.id)
        .collection('services')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .limit(1)
        .get();

    if (!mounted) return;

    if (snapshot.docs.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noServicesAvailable)));
      return;
    }

    final doc = snapshot.docs.first;
    _openAppointmentPage({...doc.data(), 'id': doc.id});
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

  Widget _buildReviewItem(Map<String, dynamic> data, {Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;
    final String reviewId = data['id'] as String;

    final List likedBy = List.from(data['likedBy'] ?? []);
    final bool firestoreIsLiked =
        currentUser != null && likedBy.contains(currentUser.uid);
    final int firestoreLikesCount = (data['likes'] ?? 0) as int;
    final reviewsCount = data['reviewerStats']?['reviewsCount'] ?? 0;
    final isTopReviewer = reviewsCount >= 10;
    final bool isLiked = _optimisticIsLiked[reviewId] ?? firestoreIsLiked;
    final int likesCount = _optimisticLikes[reviewId] ?? firestoreLikesCount;
    final bool isBusy = _likeBusy.contains(reviewId);
    final isVerified = data['reviewerStats']?['isVerified'] == true;
    final userName = data['userName'] ?? l10n.unknownUser;
    final userPhoto = data['userPhoto'];
    final userId = data['userId'];
    final rating = (data['rating'] ?? 0).toDouble();
    final text = (data['text'] ?? '').toString();

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

                  if ((photoUrl == null || photoUrl.isEmpty) &&
                      snapshot.hasData) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    photoUrl = userData?['photoUrl'];
                  }

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
                                userName.toString()[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            userName.toString()[0].toUpperCase(),
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
                          userName.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ],
                        if (isTopReviewer) ...[
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
          _buildStars(rating, size: 16),
          const SizedBox(height: 8),
          Text(text, style: AppTheme.bodyMedium()),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: isBusy
                    ? null
                    : () async {
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
                            await docRef.update({
                              'likes': FieldValue.increment(-1),
                              'likedBy': FieldValue.arrayRemove([
                                currentUser.uid,
                              ]),
                            });
                          } else {
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

  Widget _buildRatingHeader(
    double avg,
    int count,
    Map<String, int> ratingCounts,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return _sectionCard(
      title: l10n.reviewsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          ...List.generate(5, (i) {
            final star = 5 - i;
            final value = ratingCounts['$star'] ?? 0;
            final percent = count == 0 ? 0.0 : value / count;

            return Row(
              children: [
                Text('$star'),
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
                Text('$value'),
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

  Widget _buildHeader() {
    final status = _openingStatusLabel();
    final l10n = AppLocalizations.of(context)!;

    final fallbackImageUrl =
        (widget.data.logoUrl != null && widget.data.logoUrl!.isNotEmpty)
        ? widget.data.logoUrl!
        : '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.data.id)
          .snapshots()
          .distinct(
            (prev, next) => prev.data().toString() == next.data().toString(),
          ),

      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final sectorData = Map<String, dynamic>.from(data['sectorData'] ?? {});

        final groomyData = Map<String, dynamic>.from(
          sectorData['groomy'] ??
              sectorData['groomer'] ??
              sectorData['grooming'] ??
              {},
        );

        final profileContent = Map<String, dynamic>.from(
          groomyData['profileContent'] ?? groomyData['profile'] ?? {},
        );

        final liveImages = data['images'] is List
            ? List<String>.from(data['images'])
            : <String>[];

        final imageUrl =
            [
                  data['coverImageUrl'],

                  profileContent['coverImageUrl'],

                  profileContent['coverUrl'],

                  groomyData['coverImageUrl'],

                  groomyData['coverImage'],

                  if (liveImages.isNotEmpty) liveImages.first,

                  fallbackImageUrl,
                ]
                .map((e) => e?.toString().trim() ?? '')
                .firstWhere((e) => e.isNotEmpty, orElse: () => '');

        return Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,

              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,

                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          LucideIcons.scissors,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        LucideIcons.scissors,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),

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

            Positioned(
              left: 16,
              right: 16,
              bottom: 16,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    widget.data.name,

                    style: AppTheme.h1().copyWith(color: Colors.white),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _locationText,

                    style: AppTheme.bodyMedium(color: Colors.white70),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        LucideIcons.star,
                        size: 16,
                        color: Colors.amber,
                      ),

                      const SizedBox(width: 6),

                      ValueListenableBuilder<double?>(
                        valueListenable: _liveRating,

                        builder: (context, rating, _) {
                          return Text(
                            _formatRating(rating ?? widget.data.rating),

                            style: const TextStyle(color: Colors.white),
                          );
                        },
                      ),

                      const SizedBox(width: 6),

                      ValueListenableBuilder<int>(
                        valueListenable: _liveReviewCount,

                        builder: (context, count, _) {
                          return Text(
                            '(${l10n.reviewsCountLabel(count != 0 ? count : (widget.data.reviewsCount ?? 0))})',

                            style: const TextStyle(color: Colors.white70),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _badge(status),

                      if (widget.data.is24h) ...[
                        const SizedBox(width: 6),

                        _badge('24/7'),
                      ],

                      if (widget.data.isEmergency) ...[
                        const SizedBox(width: 6),

                        _badge('Emergency'),
                      ],

                      if (widget.data.isVerified) ...[
                        const SizedBox(width: 6),

                        _badge('Verified'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _badge(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(text, style: AppTheme.caption(color: Colors.black)),
    );
  }

  /*
  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label == AppLocalizations.of(context)!.workingHoursNotAvailable
            ? label
            : '$label • ${_todayHoursText()}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _smallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
*/
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
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context)!;

    final rawData = widget.data.rawData ?? {};

    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});

    final groomyData = Map<String, dynamic>.from(
      sectorData['groomy'] ??
          sectorData['groomer'] ??
          sectorData['grooming'] ??
          {},
    );

    final profileContent = Map<String, dynamic>.from(
      groomyData['profileContent'] ?? groomyData['profile'] ?? {},
    );

    final bio = (profileContent['bio'] ?? '').toString().trim();

    final about = bio.isNotEmpty ? bio : 'No groomer description available.';

    final socialMedia =
        (profileContent['socialMedia'] as Map<String, dynamic>?) ?? {};

    final instagram = (socialMedia['instagram'] ?? '').toString().trim();

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
            instagram.isNotEmpty ? instagram : l10n.instagramNotAvailable,

            style: AppTheme.bodyMedium(color: Colors.black87),
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
        final value = entry.value;
        String hoursText = '';

        if (value is Map<String, dynamic>) {
          final isOpen = value['open'] == true;
          hoursText = isOpen ? (value['hours'] ?? '').toString() : 'Closed';
        } else {
          hoursText = value.toString();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Expanded(
                flex: 4,

                child: Text(
                  entry.key.toString()[0].toUpperCase() +
                      entry.key.toString().substring(1),

                  overflow: TextOverflow.ellipsis,

                  maxLines: 1,

                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 5,

                child: Text(
                  hoursText,

                  textAlign: TextAlign.right,

                  overflow: TextOverflow.ellipsis,

                  maxLines: 1,

                  style: AppTheme.bodyMedium(color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesTab() {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.data.id)
          .collection('services')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Services could not be loaded.',
              style: AppTheme.caption(color: Colors.black54),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final services = <Map<String, dynamic>>[];

        if (docs.isNotEmpty) {
          services.addAll(
            docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .where((service) => service['isActive'] != false),
          );
        } else {
          services.addAll([]);
        }

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
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final service = services[index];
            final title = (service['title'] ?? '').toString();
            final price = _servicePrice(service);
            final duration = _serviceDuration(service);
            final description = (service['description'] ?? '')
                .toString()
                .trim();

            return GestureDetector(
              onTap: widget.onOpenAppointment == null
                  ? null
                  : () => widget.onOpenAppointment!(service),

              child: Container(
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(color: Colors.grey.shade200),
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
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            title.isEmpty ? 'Service' : title,

                            style: AppTheme.bodyMedium(),
                          ),

                          if (price > 0 || duration > 0) ...[
                            const SizedBox(height: 4),

                            Text(
                              [
                                if (price > 0) '₺$price',

                                if (duration > 0) duration.toString(),
                              ].join(' • '),

                              style: AppTheme.caption(color: Colors.black54),
                            ),
                          ],

                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),

                            Text(
                              description,

                              style: AppTheme.caption(color: Colors.black45),
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
      },
    );
  }

  Widget _buildReviewsTab() {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getReviewsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
        double avg = 0;
        for (var doc in reviews) {
          avg += (doc['rating'] ?? 0).toDouble();
        }
        avg = avg / reviews.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_liveRating.value != avg) {
            _liveRating.value = avg;
          }
          if (_liveReviewCount.value != reviews.length) {
            _liveReviewCount.value = reviews.length;
          }
        });

        final ratingCounts = <String, int>{
          '1': 0,
          '2': 0,
          '3': 0,
          '4': 0,
          '5': 0,
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
            _buildSortToggle(),
            _buildRatingHeader(avg, reviews.length, ratingCounts),
            const SizedBox(height: 16),
            ...reviews.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return _buildReviewItem(data, key: ValueKey(doc.id));
            }),
          ],
        );
      },
    );
  }

  Widget _buildGalleryTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.data.id)
          .snapshots(),

      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final sectorData = Map<String, dynamic>.from(data['sectorData'] ?? {});

        final groomyData = Map<String, dynamic>.from(
          sectorData['groomy'] ??
              sectorData['groomer'] ??
              sectorData['grooming'] ??
              {},
        );

        final profileContent = Map<String, dynamic>.from(
          groomyData['profileContent'] ?? groomyData['profile'] ?? {},
        );

        final images = <String>{
          ..._stringList(data['images']),

          ..._stringList(data['clinicPhotoUrls']),

          ..._stringList(profileContent['photos']),

          ..._stringList(profileContent['clinicPhotoUrls']),

          ..._stringList(groomyData['coverImage']),

          ..._stringList(groomyData['coverImageUrl']),
        }.where((e) => e.trim().isNotEmpty).toList();

        if (images.isEmpty) {
          return const Center(child: Text('No images'));
        }

        final media = images
            .map((e) => MediaItem(url: e, type: MediaType.image))
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),

          itemCount: images.length,

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,

            crossAxisSpacing: 8,

            mainAxisSpacing: 8,
          ),

          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                _openGalleryViewer(media, index);
              },

              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: Image.network(
                  images[index],

                  fit: BoxFit.cover,

                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: Colors.grey.shade200,

                      child: const Center(child: Icon(Icons.image)),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').toList();
    }

    final text = value?.toString() ?? '';

    return text.trim().isEmpty ? <String>[] : [text];
  }

  Widget _contactButton(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;

    return Expanded(
      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(14),

          child: Container(
            height: 56,

            decoration: BoxDecoration(
              color: enabled ? Colors.amber : Colors.white,

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: Colors.black12),
            ),

            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      icon,

                      size: 18,

                      color: enabled ? Colors.black : Colors.grey,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      label,

                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,

                        color: enabled ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
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
                                onPressed: _openFirstAvailableService,
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
}

class _WriteReviewSheet extends StatefulWidget {
  final String groomyId;

  const _WriteReviewSheet({required this.groomyId});

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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to continue')));
      return;
    }

    final text = _reviewController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnap.data() ?? {};
      final reviewerStats = userData['reviewerStats'] is Map
          ? Map<String, dynamic>.from(userData['reviewerStats'])
          : <String, dynamic>{};

      await FirebaseFirestore.instance.collection('reviews').add({
        'businessId': widget.groomyId,
        'businessType': 'groomy',
        'userId': user.uid,
        'userName':
            userData['displayName']?.toString().trim().isNotEmpty == true
            ? userData['displayName']
            : (user.displayName ?? l10n.unknownUser),
        'userPhoto': userData['photoUrl'] ?? user.photoURL,
        'rating': _reviewRating,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'rankScore': 0,
        'reviewerStats': {
          'reviewsCount': reviewerStats['reviewsCount'] ?? 0,
          'totalLikes': reviewerStats['totalLikes'] ?? 0,
          'trustScore': reviewerStats['trustScore'] ?? 0,
          'isVerified': reviewerStats['isVerified'] ?? false,
        },
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorSubmittingReview}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.writeAReview,
                  style: AppTheme.h2().copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      onPressed: () =>
                          setState(() => _reviewRating = star.toDouble()),
                      icon: Icon(
                        _reviewRating >= star ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewController,
                  focusNode: _reviewFocusNode,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Tell others about your experience',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
