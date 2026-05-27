import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

enum ReviewSortType {
  mostRelevant,
  newest,
}

class PetHotelReviewsTab extends StatefulWidget {
  final String businessId;

  const PetHotelReviewsTab({
    super.key,
    required this.businessId,
  });

  @override
  State<PetHotelReviewsTab> createState() =>
      _PetHotelReviewsTabState();
}

class _PetHotelReviewsTabState
    extends State<PetHotelReviewsTab> {
  ReviewSortType _sortType =
      ReviewSortType.mostRelevant;

  final Map<String, int> _optimisticLikes = {};
  final Map<String, bool> _optimisticIsLiked = {};
  final Set<String> _likeBusy = {};

  double? _liveRating;
  int _liveReviewCount = 0;

  Stream<QuerySnapshot> _getReviewsStream() {
    final collection = FirebaseFirestore.instance
        .collection('reviews')
        .where(
          'businessId',
          isEqualTo: widget.businessId,
        );

    if (_sortType == ReviewSortType.newest) {
      return collection
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots();
    } else {
      return collection
          .orderBy(
            'rankScore',
            descending: true,
          )
          .snapshots();
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

          _buildSortItem(
            title: l10n.newest,
            type: ReviewSortType.newest,
          ),
        ],
      ),
    );
  }

  Widget _buildSortItem({
    required String title,
    required ReviewSortType type,
  }) {
    final isSelected = _sortType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _sortType = type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 200,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.black
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStars(
    double rating, {
    double size = 18,
  }) {
    return Row(
      children: List.generate(5, (index) {
        if (rating >= index + 1) {
          return Icon(
            Icons.star,
            color: Colors.amber,
            size: size,
          );
        } else if (rating >= index + 0.25 &&
            rating < index + 0.75) {
          return Icon(
            Icons.star_half,
            color: Colors.amber,
            size: size,
          );
        } else {
          return Icon(
            Icons.star_border,
            color: Colors.amber,
            size: size,
          );
        }
      }),
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
        borderRadius:
            BorderRadius.circular(18),
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
            style: AppTheme.bodyMedium()
                .copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),

          const SizedBox(height: 10),

          child,
        ],
      ),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: AppTheme.h1(),
              ),

              const SizedBox(width: 8),

              _buildStars(avg),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            l10n.reviewsCountLabel(count),
          ),

          const SizedBox(height: 12),

          ...List.generate(5, (i) {
            int star = 5 - i;

            int value =
                ratingCounts["$star"] ?? 0;

            double percent = count == 0
                ? 0
                : value / count;

            return Row(
              children: [
                Text("$star"),

                const SizedBox(width: 6),

                const Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor:
                        Colors.grey.shade200,
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
            label: Text(
              l10n.writeAReview,
            ),
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

    if (diff.inSeconds < 60) {
      return l10n.justNow;
    }

    if (diff.inMinutes < 60) {
      return l10n.minutesAgo(
        diff.inMinutes,
      );
    }

    if (diff.inHours < 24) {
      return l10n.hoursAgo(
        diff.inHours,
      );
    }

    if (diff.inDays < 7) {
      return l10n.daysAgo(
        diff.inDays,
      );
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildReviewItem(
    Map<String, dynamic> data, {
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context)!;

    final currentUser =
        FirebaseAuth.instance.currentUser;

    final String reviewId =
        data['id'] as String;

    final List likedBy = List.from(
      data['likedBy'] ?? [],
    );

    final bool firestoreIsLiked =
        currentUser != null &&
            likedBy.contains(
              currentUser.uid,
            );

    final int firestoreLikesCount =
        (data['likes'] ?? 0) as int;

    final reviewsCount =
        data['reviewerStats']
                ?['reviewsCount'] ??
            0;

    final bool isLiked =
        _optimisticIsLiked[reviewId] ??
            firestoreIsLiked;

    final int likesCount =
        _optimisticLikes[reviewId] ??
            firestoreLikesCount;

    final bool isBusy =
        _likeBusy.contains(reviewId);

    final isVerified =
        data['reviewerStats']
                ?['isVerified'] ==
            true;

    final userName =
        data['userName'] ??
            l10n.unknownUser;

    final userPhoto =
        data['userPhoto'];

    final userId = data['userId'];

    return Container(
      key: key,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              (data['rankScore'] ?? 0) > 80
              ? Colors.green
              : Colors.grey.shade200,
          width:
              (data['rankScore'] ?? 0) > 80
              ? 1.5
              : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore
                    .instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder:
                    (context, snapshot) {
                  String? photoUrl =
                      userPhoto;

                  if ((photoUrl == null ||
                          photoUrl
                              .isEmpty) &&
                      snapshot.hasData) {
                    final userData =
                        snapshot.data!
                                .data()
                            as Map<
                              String,
                              dynamic
                            >?;

                    photoUrl =
                        userData?['photoUrl'];
                  }

                  if ((photoUrl == null ||
                          photoUrl
                              .isEmpty) &&
                      FirebaseAuth
                              .instance
                              .currentUser
                              ?.uid ==
                          userId) {
                    photoUrl =
                        FirebaseAuth
                            .instance
                            .currentUser
                            ?.photoURL;
                  }

                  final hasPhoto =
                      photoUrl != null &&
                          photoUrl
                              .isNotEmpty;

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppTheme.primary
                            .withOpacity(
                              0.1,
                            ),
                    child: hasPhoto
                        ? ClipOval(
                            child:
                                Image.network(
                                  photoUrl,
                                  width: 32,
                                  height: 32,
                                  fit:
                                      BoxFit
                                          .cover,
                                  errorBuilder:
                                      (
                                        _,
                                        __,
                                        ___,
                                      ) => Text(
                                        userName[0]
                                            .toUpperCase(),
                                        style:
                                            TextStyle(
                                              color:
                                                  AppTheme.primary,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                      ),
                                ),
                          )
                        : Text(
                            userName[0]
                                .toUpperCase(),
                            style:
                                TextStyle(
                                  color:
                                      AppTheme.primary,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                  );
                },
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style:
                              const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                        ),

                        if (isVerified) ...[
                          const SizedBox(
                            width: 6,
                          ),

                          const Icon(
                            Icons.verified,
                            size: 16,
                            color:
                                Colors.blue,
                          ),
                        ],

                        if (reviewsCount >=
                            10) ...[
                          const SizedBox(
                            width: 6,
                          ),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                  horizontal:
                                      6,
                                  vertical: 2,
                                ),
                            decoration:
                                BoxDecoration(
                                  color: Colors
                                      .purple
                                      .withOpacity(
                                        0.1,
                                      ),
                                  borderRadius:
                                      BorderRadius.circular(
                                        6,
                                      ),
                                ),
                            child: Text(
                              l10n.topLabel,
                              style:
                                  const TextStyle(
                                    fontSize:
                                        10,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    color:
                                        Colors
                                            .purple,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    Text(
                      _timeAgo(
                        data['createdAt']
                            as Timestamp?,
                      ),
                      style:
                          AppTheme.caption(
                            color:
                                Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _buildStars(
            (data['rating'] ?? 0)
                .toDouble(),
            size: 16,
          ),

          const SizedBox(height: 8),

          Text(
            data['text'] ?? '',
            style: AppTheme.bodyMedium(),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              IconButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        if (currentUser ==
                            null) {
                          return;
                        }

                        final docRef =
                            FirebaseFirestore
                                .instance
                                .collection(
                                  'reviews',
                                )
                                .doc(
                                  reviewId,
                                );

                        final bool nextIsLiked =
                            !isLiked;

                        final int nextLikes =
                            nextIsLiked
                            ? likesCount + 1
                            : likesCount - 1;

                        setState(() {
                          _likeBusy.add(
                            reviewId,
                          );

                          _optimisticIsLiked[reviewId] =
                              nextIsLiked;

                          _optimisticLikes[reviewId] =
                              nextLikes < 0
                              ? 0
                              : nextLikes;
                        });

                        try {
                          if (isLiked) {
                            await docRef
                                .update({
                                  'likes':
                                      FieldValue.increment(
                                        -1,
                                      ),

                                  'likedBy':
                                      FieldValue.arrayRemove(
                                        [
                                          currentUser
                                              .uid,
                                        ],
                                      ),
                                });
                          } else {
                            await docRef
                                .update({
                                  'likes':
                                      FieldValue.increment(
                                        1,
                                      ),

                                  'likedBy':
                                      FieldValue.arrayUnion(
                                        [
                                          currentUser
                                              .uid,
                                        ],
                                      ),
                                });
                          }

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _likeBusy.remove(
                              reviewId,
                            );
                          });
                        } catch (e) {
                          debugPrint(
                            '🔥 LIKE ERROR: $e',
                          );

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _likeBusy.remove(
                              reviewId,
                            );

                            _optimisticIsLiked
                                .remove(
                                  reviewId,
                                );

                            _optimisticLikes
                                .remove(
                                  reviewId,
                                );
                          });

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n
                                    .couldNotUpdateLike,
                              ),
                            ),
                          );
                        }
                      },
                icon: Icon(
                  isLiked
                      ? Icons.thumb_up
                      : Icons
                            .thumb_up_outlined,
                  size: 18,
                  color: isLiked
                      ? AppTheme.primary
                      : Colors.grey,
                ),
              ),

              Text(
                '$likesCount',
                style: AppTheme.caption(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openWriteReviewSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _WriteReviewSheet(
        businessId: widget.businessId,
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
              Text(
                l10n.noReviewsYet,
                style: AppTheme.bodyMedium(),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed:
                    _openWriteReviewSheet,
                child: Text(
                  l10n.beFirstToReview,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: _getReviewsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '🔥 FIRESTORE ERROR: ${snapshot.error}',
          );

          return Center(
            child: Text(
              l10n.errorLoadingReviews(
                snapshot.error.toString(),
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return _emptyReviewsState();
        }

        final reviews =
            snapshot.data!.docs;

        double avg = 0;

        for (var doc in reviews) {
          avg +=
              (doc['rating'] ?? 0)
                  .toDouble();
        }

        avg = avg / reviews.length;

        WidgetsBinding.instance
            .addPostFrameCallback((_) {
              if (mounted &&
                  (_liveRating != avg ||
                      _liveReviewCount !=
                          reviews.length)) {
                setState(() {
                  _liveRating = avg;
                  _liveReviewCount =
                      reviews.length;
                });
              }
            });

        Map<String, int> ratingCounts =
            {
              "1": 0,
              "2": 0,
              "3": 0,
              "4": 0,
              "5": 0,
            };

        for (var doc in reviews) {
          final r =
              (doc['rating'] ?? 0)
                  .toInt()
                  .toString();

          if (ratingCounts.containsKey(
            r,
          )) {
            ratingCounts[r] =
                ratingCounts[r]! + 1;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            _buildSortToggle(),

            _buildRatingHeader(
              avg,
              reviews.length,
              ratingCounts,
            ),

            const SizedBox(height: 16),

            ...reviews.map((doc) {
              final data =
                  Map<String, dynamic>.from(
                    doc.data()
                        as Map<
                          String,
                          dynamic
                        >,
                  );

              data['id'] = doc.id;

              return _buildReviewItem(
                data,
                key: ValueKey(doc.id),
              );
            }),
          ],
        );
      },
    );
  }
}

class _WriteReviewSheet
    extends StatefulWidget {
  final String businessId;

  const _WriteReviewSheet({
    required this.businessId,
  });

  @override
  State<_WriteReviewSheet> createState() =>
      _WriteReviewSheetState();
}

class _WriteReviewSheetState
    extends State<_WriteReviewSheet> {
  final TextEditingController
  _reviewController =
      TextEditingController();

  double _reviewRating = 5;

  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final l10n =
          AppLocalizations.of(context)!;

      final text =
          _reviewController.text.trim();

      if (text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  l10n
                      .pleaseWriteSomething,
                ),
              ),
            );

        return;
      }

      final currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        return;
      }

      final existing =
          await FirebaseFirestore
              .instance
              .collection('reviews')
              .where(
                'businessId',
                isEqualTo:
                    widget.businessId,
              )
              .where(
                'userId',
                isEqualTo:
                    currentUser.uid,
              )
              .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  l10n
                      .alreadyReviewedThisVet,
                ),
              ),
            );

        return;
      }

      final userDoc =
          await FirebaseFirestore
              .instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final userData =
          userDoc.data() ?? {};

      final userName =
          userData['username'] ??
              l10n.unknownUser;

      final userPhoto =
          userData['photoUrl'] ??
              currentUser.photoURL;

      final userReviews =
          await FirebaseFirestore
              .instance
              .collection('reviews')
              .where(
                'userId',
                isEqualTo:
                    currentUser.uid,
              )
              .get();

      await FirebaseFirestore
          .instance
          .collection('reviews')
          .add({
            'businessId':
                widget.businessId,

            'userId': currentUser.uid,

            'userName': userName,

            'userPhoto': userPhoto,

            'rating': _reviewRating,

            'text': text,

            'createdAt':
                FieldValue.serverTimestamp(),

            'likes': 0,

            'likedBy': [],

            'rankScore': 0,

            'reviewerStats': {
              'reviewsCount':
                  userReviews.docs.length,

              'totalLikes': 0,

              'trustScore': 0,

              'isVerified':
                  currentUser
                      .emailVerified,

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

      Navigator.pop(context);
    } catch (e) {
      debugPrint(
        '🔥 REVIEW ERROR: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (
        context,
        scrollController,
      ) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom:
                MediaQuery.of(
                  context,
                ).viewInsets.bottom +
                16,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.writeAReview,
                  style: AppTheme.h2(),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: List.generate(
                    5,
                    (index) {
                      return IconButton(
                        onPressed:
                            _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _reviewRating =
                                      index +
                                      1.0;
                                });
                              },
                        icon: Icon(
                          Icons.star,
                          size: 30,
                          color:
                              index <
                                  _reviewRating
                              ? Colors.amber
                              : Colors
                                    .grey
                                    .shade300,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller:
                      _reviewController,
                  maxLines: 4,
                  decoration:
                      InputDecoration(
                        hintText:
                            l10n
                                .shareYourExperienceHint,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                                14,
                              ),
                        ),
                      ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting
                        ? null
                        : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors
                                          .white,
                                ),
                          )
                        : Text(
                            l10n.submit,
                            style:
                                const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}