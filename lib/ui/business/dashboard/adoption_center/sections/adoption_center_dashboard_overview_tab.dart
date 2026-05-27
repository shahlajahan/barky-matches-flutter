import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class AdoptionCenterDashboardOverviewTab
    extends StatelessWidget {

  final String businessId;

  final Map<String, dynamic>
      businessData;

  const AdoptionCenterDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  Widget build(BuildContext context) {

    final profile =
        Map<String, dynamic>.from(
      businessData['profile'] ?? {},
    );

    final contact =
        Map<String, dynamic>.from(
      businessData['contact'] ?? {},
    );

    return ListView(

      padding:
          const EdgeInsets.all(16),

      children: [

        /// ================= PROFILE =================

        _SectionTitle(
          "Adoption Center Profile",
        ),

        const SizedBox(
          height: 10,
        ),

        _profileCard(
          context,
          profile,
          contact,
        ),

        const SizedBox(
          height: 20,
        ),

        /// ================= REQUESTS =================

        _SectionTitle(
          "Recent Adoption Requests",
        ),

        const SizedBox(
          height: 10,
        ),

        StreamBuilder<QuerySnapshot>(

          stream:
              FirebaseFirestore
                  .instance
                  .collection(
                    'adoption_center_requests',
                  )
                  .where(
                    'businessId',
                    isEqualTo:
                        businessId,
                  )
                  
                  .snapshots(),

          builder: (
            context,
            snapshot,
          ) {

            debugPrint(
              "🐾 ADOPTION REQUEST STREAM",
            );

            debugPrint(
              "🐾 businessId = $businessId",
            );

            if (snapshot.hasError) {

              return _emptyBox(
                "Request error: ${snapshot.error}",
              );
            }

            if (snapshot.connectionState ==
                ConnectionState.waiting) {

              return _emptyBox(
                "Loading requests...",
              );
            }

            if (!snapshot.hasData) {

              return _emptyBox(
                "No request data",
              );
            }

            final docs =
                snapshot.data!.docs
                    .toList();

            if (docs.isEmpty) {

              return _emptyBox(
                "No adoption requests yet",
              );
            }

            docs.sort((a, b) {

              final aData =
                  a.data()
                      as Map<
                        String,
                        dynamic
                      >;

              final bData =
                  b.data()
                      as Map<
                        String,
                        dynamic
                      >;

              final aStatus =
                  aData['status'] ??
                      '';

              final bStatus =
                  bData['status'] ??
                      '';

              if (aStatus ==
                      'pending' &&
                  bStatus !=
                      'pending') {

                return -1;
              }

              if (aStatus !=
                      'pending' &&
                  bStatus ==
                      'pending') {

                return 1;
              }

              final aTs =
                  aData['createdAt'];

              final bTs =
                  bData['createdAt'];

              final aTime =
                  aTs is Timestamp
                  ? aTs.toDate()
                  : null;

              final bTime =
                  bTs is Timestamp
                  ? bTs.toDate()
                  : null;

              if (aTime == null ||
                  bTime == null) {

                return 0;
              }

              return bTime.compareTo(
                aTime,
              );
            });

            final pending =
                docs
                    .where((d) {

                      final data =
                          d.data()
                              as Map<
                                String,
                                dynamic
                              >;

                      return data['status'] ==
                          'pending';
                    })
                    .take(3)
                    .toList();

            final total =
                docs.length;

            final pendingCount =
                docs.where((d) {

                  final data =
                      d.data()
                          as Map<
                            String,
                            dynamic
                          >;

                  return data['status'] ==
                      'pending';
                }).length;

            final approvedCount =
                docs.where((d) {

                  final data =
                      d.data()
                          as Map<
                            String,
                            dynamic
                          >;

                  return data['status'] ==
                      'approved';
                }).length;

            final completedCount =
                docs.where((d) {

                  final data =
                      d.data()
                          as Map<
                            String,
                            dynamic
                          >;

                  return data['status'] ==
                      'completed';
                }).length;

            return Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Row(
                  children: [

                    _KpiCard(
                      title:
                          "Total",
                      value:
                          "$total",
                      icon:
                          LucideIcons
                              .heartHandshake,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    _KpiCard(
                      title:
                          "Pending",
                      value:
                          "$pendingCount",
                      icon:
                          LucideIcons
                              .clock,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [

                    _KpiCard(
                      title:
                          "Approved",
                      value:
                          "$approvedCount",
                      icon:
                          LucideIcons
                              .checkCircle,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    _KpiCard(
                      title:
                          "Completed",
                      value:
                          "$completedCount",
                      icon:
                          LucideIcons
                              .check,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                _SectionTitle(
                  "Pending Adoption Requests",
                ),

                const SizedBox(
                  height: 8,
                ),

                if (pending.isEmpty)

                  _emptyBox(
                    "No pending adoption requests",
                  )

                else

                  ...pending.map((doc) {

                    final data =
                        doc.data()
                            as Map<
                              String,
                              dynamic
                            >;

                    return _requestItem(
                      context,
                      doc.id,
                      data,
                    );
                  }),
              ],
            );
          },
        ),

        const SizedBox(
          height: 24,
        ),

        /// ================= QUICK ACTIONS =================

        _SectionTitle(
          "Quick Actions",
        ),

        const SizedBox(
          height: 10,
        ),

        Row(
          children: [

            _actionBtn(
              "Add Pet",
              Icons.pets,
            ),

            const SizedBox(
              width: 10,
            ),

            _actionBtn(
              "Requests",
              LucideIcons
                  .heartHandshake,
            ),

            const SizedBox(
              width: 10,
            ),

            _actionBtn(
              "Settings",
              LucideIcons.settings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _requestItem(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {

    final status =
        data['status'] ??
            'pending';

    final petName =
        data['petName'] ??
            '';

    final breed =
        data['petBreed'] ??
            '-';

    final requesterName =
        data['requesterName'] ??
            'User';

    final ts =
        data['createdAt'];

    final dt =
        ts is Timestamp
        ? ts.toDate()
        : null;

    String dateText = '';

    if (dt != null) {

      dateText =
          "${dt.year}-${dt.month}-${dt.day}";
    }

    Color statusColor;

    switch (status) {

      case 'approved':
        statusColor =
            Colors.green;
        break;

      case 'rejected':
        statusColor =
            Colors.red;
        break;

      case 'completed':
        statusColor =
            Colors.blue;
        break;

      default:
        statusColor =
            Colors.orange;
    }

    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          _cardDecoration(),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [

          Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [

              Expanded(
                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [

                    Text(
                      petName,

                      style:
                          AppTheme
                              .bodyMedium()
                              .copyWith(
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      "Breed: $breed",

                      style:
                          AppTheme
                              .caption(),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      "Requester: $requesterName",

                      style:
                          AppTheme
                              .caption(),
                    ),
                  ],
                ),
              ),

              Container(

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),

                decoration:
                    BoxDecoration(

                  color: statusColor
                      .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),

                child: Text(

                  status
                      .toUpperCase(),

                  style: TextStyle(

                    color:
                        statusColor,

                    fontWeight:
                        FontWeight
                            .w600,

                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            dateText,
            style:
                AppTheme.caption(),
          ),

          const SizedBox(
            height: 10,
          ),

          if (status == 'pending')

            Row(
              children: [

                Expanded(
                  child:
                      ElevatedButton(

                    onPressed: () {

                      _updateRequestStatus(
                        context,
                        id,
                        'approved',
                      );
                    },

                    child:
                        const Text(
                      "Approve",
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      ElevatedButton(

                    onPressed: () {

                      _updateRequestStatus(
                        context,
                        id,
                        'rejected',
                      );
                    },

                    child:
                        const Text(
                      "Reject",
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void>
  _updateRequestStatus(
    BuildContext context,
    String requestId,
    String newStatus,
  ) async {

    try {

      await FirebaseFunctions
          .instanceFor(
            region:
                'europe-west3',
          )
          .httpsCallable(
            'updateAdoptionCenterRequestStatus',
          )
          .call({

            'requestId':
                requestId,

            'newStatus':
                newStatus,
          });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(

          content: Text(
            "Request updated: $newStatus",
          ),
        ),
      );
    } catch (e) {

      debugPrint(
        "❌ ADOPTION UPDATE ERROR: $e",
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(

          content: Text(
            "Update failed: $e",
          ),
        ),
      );
    }
  }

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic> contact,
  ) {

    final name =
        profile['displayName'] ??
            'Adoption Center';

    final description =
        profile['description'] ??
            "No description yet";

    return Container(

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          _cardDecoration(),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [

          Row(
            children: [

              Expanded(
                child: Text(

                  name,

                  style:
                      AppTheme
                          .h3(
                            weight:
                                FontWeight
                                    .w800,
                          ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(

            description,

            style: AppTheme.body(
              color:
                  AppTheme.muted,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children: [

              _chip(
                "📞 ${contact['phone'] ?? '-'}",
              ),

              _chip(
                "📍 ${contact['city'] ?? '-'}",
              ),

              _chip(
                "📍 ${contact['district'] ?? '-'}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration
  _cardDecoration() {

    return BoxDecoration(

      color: Colors.white,

      borderRadius:
          BorderRadius.circular(
        16,
      ),

      border: Border.all(
        color: Colors.black12,
      ),

      boxShadow:
          AppTheme.cardShadow(
        opacity: 0.06,
      ),
    );
  }

  Widget _emptyBox(
    String text,
  ) {

    return Container(

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          _cardDecoration(),

      child: Text(

        text,

        style: AppTheme.body(
          color:
              AppTheme.muted,
        ),
      ),
    );
  }

  Widget _chip(
    String text,
  ) {

    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(

        color: const Color(
          0xFF9E1B4F,
        ).withOpacity(0.08),

        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),

      child: Text(

        text,

        style:
            AppTheme.caption(
          color: const Color(
            0xFF9E1B4F,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {

  final String title;

  const _SectionTitle(
    this.title,
  );

  @override
  Widget build(
    BuildContext context,
  ) {

    return Text(
      title,
      style: AppTheme.h2(),
    );
  }
}

class _KpiCard
    extends StatelessWidget {

  final String title;

  final String value;

  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return Expanded(
      child: Container(

        padding:
            const EdgeInsets.all(
          14,
        ),

        decoration:
            BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          border: Border.all(
            color: const Color(
              0xFF9E1B4F,
            ).withOpacity(
              0.15,
            ),
          ),
        ),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [

            Icon(
              icon,

              size: 18,

              color: const Color(
                0xFF9E1B4F,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(

              value,

              style:
                  AppTheme.h2(
                    weight:
                        FontWeight
                            .w800,
                  ),
            ),

            Text(
              title,
              style:
                  AppTheme.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

class _actionBtn
    extends StatelessWidget {

  final String text;

  final IconData icon;

  const _actionBtn(
    this.text,
    this.icon,
  );

  @override
  Widget build(
    BuildContext context,
  ) {

    return Expanded(
      child: Container(

        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border: Border.all(
            color: Colors.black12,
          ),
        ),

        child: Column(
          children: [

            Icon(
              icon,

              color: const Color(
                0xFF9E1B4F,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(text),
          ],
        ),
      ),
    );
  }
}