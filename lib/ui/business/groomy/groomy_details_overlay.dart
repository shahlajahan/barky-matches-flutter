import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

import 'package:firebase_auth/firebase_auth.dart';


import 'package:barky_matches_fixed/l10n/app_localizations.dart';

enum _GroomyDetailsTab { overview, services, reviews, gallery }
enum ReviewSortType {
  mostRelevant,
  newest,
}

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

class _GroomyDetailsOverlayState extends State<GroomyDetailsOverlay> {
  _GroomyDetailsTab _activeTab = _GroomyDetailsTab.overview;
ReviewSortType _sortType =
    ReviewSortType.mostRelevant;

final Map<String, int>
    _optimisticLikes = {};

final Map<String, bool>
    _optimisticIsLiked = {};

final Set<String>
    _likeBusy = {};

double? _liveRating;

int _liveReviewCount = 0;
  List<Map<String, dynamic>> _fallbackServices() {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    final groomingData = Map<String, dynamic>.from(
      sectorData['grooming'] ?? sectorData['groomer'] ?? {},
    );
    final servicesData = groomingData['services'];

    

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

  List<String> _galleryImages() {
    final rawData = widget.data.rawData ?? widget.data.data ?? {};
    final sectorData = Map<String, dynamic>.from(rawData['sectorData'] ?? {});
    final groomingData = Map<String, dynamic>.from(
      sectorData['grooming'] ?? sectorData['groomer'] ?? {},
    );
    final profileContent = Map<String, dynamic>.from(
      groomingData['profileContent'] ?? groomingData['media'] ?? {},
    );

    final images = <String>[
      ..._stringList(rawData['images']),
      ..._stringList(rawData['clinicPhotoUrls']),
      ..._stringList(profileContent['clinicPhotoUrls']),
      ..._stringList(profileContent['photos']),
      ..._stringList(groomingData['coverImage']),
      ..._stringList(widget.data.logoUrl),
    ];

    return images.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    final text = value?.toString() ?? '';
    return text.trim().isEmpty ? <String>[] : <String>[text];
  }

  double _servicePrice(Map<String, dynamic> service) {
    final raw = service['price'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _serviceDuration(Map<String, dynamic> service) {
    final raw = service['durationMin'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 60;
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
    builder: (_) => _WriteReviewSheet(
      businessId: widget.data.id,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _header(),
                      _tabBar(),
                      Expanded(child: _tabContent()),
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

   Stream<QuerySnapshot> _getReviewsStream() {
    final collection = FirebaseFirestore.instance
        .collection('reviews')
        .where('businessId', isEqualTo: widget.data.id)
.where(
  'businessType',
  isEqualTo: 'groomy',
);

    if (_sortType == ReviewSortType.newest) {
      return collection.orderBy('createdAt', descending: true).snapshots();
    } else {
      return collection.orderBy('rankScore', descending: true).snapshots();
    }
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
            }),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      color: const Color(0xFF9E1B4F),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.h2(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.data.district}, ${widget.data.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: _GroomyDetailsTab.values.map((tab) {
          final selected = _activeTab == tab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? Colors.amber : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _tabTitle(tab),
                  textAlign: TextAlign.center,
                  style: AppTheme.caption().copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _tabTitle(_GroomyDetailsTab tab) {
    switch (tab) {
      case _GroomyDetailsTab.overview:
        return 'Overview';
      case _GroomyDetailsTab.services:
        return 'Services';
      case _GroomyDetailsTab.reviews:
  return 'Reviews';
      case _GroomyDetailsTab.gallery:
        return 'Gallery';
    }
  }

  Widget _tabContent() {
    switch (_activeTab) {
      case _GroomyDetailsTab.overview:
        return _overview();
      case _GroomyDetailsTab.services:
        return _services();
      case _GroomyDetailsTab.reviews:
        return _buildReviewsTab();
      case _GroomyDetailsTab.gallery:
        return _gallery();
    }
  }

  Widget _overview() {
    final specialties = widget.data.specialties.isNotEmpty
        ? widget.data.specialties
        : widget.data.services ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((widget.data.description ?? '').trim().isNotEmpty) ...[
          Text(widget.data.description!, style: AppTheme.body()),
          const SizedBox(height: 16),
        ],
        if (specialties.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties
                .map(
                  (item) =>
                      Chip(label: Text(item), backgroundColor: Colors.white),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _contactButton(LucideIcons.phone, widget.onCall),
            const SizedBox(width: 10),
            _contactButton(LucideIcons.messageCircle, widget.onWhatsApp),
            const SizedBox(width: 10),
            _contactButton(LucideIcons.navigation, widget.onDirections),
          ],
        ),
      ],
    );
  }

  Widget _services() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.data.id)
          .collection('services')
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = <Map<String, dynamic>>[];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          services.addAll(
            snapshot.data!.docs
                .map((doc) {
                  final data = doc.data();
                  return {...data, 'id': doc.id};
                })
                .where((service) => service['isActive'] != false),
          );
        } else {
          services.addAll(_fallbackServices());
        }

        if (services.isEmpty) {
          return const Center(child: Text('No services available'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final service = services[index];
            final title = service['title']?.toString() ?? '';
            final price = _servicePrice(service);
            final duration = _serviceDuration(service);

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onOpenAppointment == null
                    ? null
                    : () => widget.onOpenAppointment!(service),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.scissors, size: 20),
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
                              '$duration min',
                              style: AppTheme.caption(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (price > 0)
                        Text(
                          '₺${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                          style: AppTheme.body().copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _sectionCard({
  required String title,
  required Widget child,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.grey.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.body().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 10),

        child,
      ],
    ),
  );
}

  Widget _gallery() {
    final images = _galleryImages();
    if (images.isEmpty) {
      return const Center(child: Text('No gallery images yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        );
      },
    );
  }

  Widget _contactButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? Colors.amber : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: enabled ? Colors.black : Colors.grey),
      ),
    );
  }
}
class _WriteReviewSheet extends StatefulWidget {
  final String businessId;

  const _WriteReviewSheet({
  required this.businessId,
});

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

      final businessId =
    widget.businessId;

      final existing = await FirebaseFirestore.instance
          .collection('reviews')
          .where(
  'businessId',
  isEqualTo: businessId,
)
.where(
  'businessType',
  isEqualTo: 'groomy',
)
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
        'businessId': businessId,
'businessType': 'groomy',
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
