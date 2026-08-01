import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/widgets/business_quick_actions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdoptionCenterDashboardOverviewTab extends StatefulWidget {
  final String businessId;

  final Map<String, dynamic> businessData;

  final VoidCallback? onOpenPets;

  final VoidCallback? onOpenRequests;

  final VoidCallback? onOpenSettings;

  const AdoptionCenterDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
    this.onOpenPets,
    this.onOpenRequests,
    this.onOpenSettings,
  });

  @override
  State<AdoptionCenterDashboardOverviewTab> createState() =>
      _AdoptionCenterDashboardOverviewTabState();
}

class _AdoptionCenterDashboardOverviewTabState
    extends State<AdoptionCenterDashboardOverviewTab> {
  late final Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();

    debugPrint('🐾 OVERVIEW STREAM targetOwnerId=${widget.businessId}');

    _requestsStream = FirebaseFirestore.instance
        .collection('adoption_requests')
        .where('targetOwnerId', isEqualTo: widget.businessId)
        //.orderBy('createdAt', descending: true)
        //.limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      widget.businessData['profile'] ?? {},
    );

    final contact = Map<String, dynamic>.from(
      widget.businessData['contact'] ?? {},
    );

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        /// ================= PROFILE =================
        _SectionTitle("Adoption Center Profile"),

        const SizedBox(height: 10),

        _profileCard(context, profile, contact),

        const SizedBox(height: 20),

        /// ================= REQUESTS =================
        _SectionTitle("Recent Adoption Requests"),

        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: _requestsStream,

          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _emptyBox("Request error: ${snapshot.error}");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _emptyBox("Loading requests...");
            }

            if (!snapshot.hasData) {
              return _emptyBox("No request data");
            }

            final docs = snapshot.data!.docs.toList();

            if (docs.isEmpty) {
              return _emptyBox("No adoption requests yet");
            }

            final total = docs.length;

            final pendingCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'pending';
            }).length;

            final approvedCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'approved';
            }).length;

            final completedCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'completed';
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    _KpiCard(
                      title: "Total",
                      value: "$total",
                      icon: LucideIcons.heartHandshake,
                    ),

                    const SizedBox(width: 10),

                    _KpiCard(
                      title: "Pending",
                      value: "$pendingCount",
                      icon: LucideIcons.clock,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _KpiCard(
                      title: "Approved",
                      value: "$approvedCount",
                      icon: LucideIcons.checkCircle,
                    ),

                    const SizedBox(width: 10),

                    _KpiCard(
                      title: "Completed",
                      value: "$completedCount",
                      icon: LucideIcons.check,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _SectionTitle("Recent Adoption Requests"),

                          const SizedBox(height: 4),

                          Text(
                            AppLocalizations.of(context)!.latestAdoptionApplications,

                            style: AppTheme.caption(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: widget.onOpenRequests,

                      child: Text(AppLocalizations.of(context)!.viewAll),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (docs.isEmpty)
                  _emptyBox("No adoption requests yet")
                else
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return _AdoptionRequestItem(
                      key: ValueKey(doc.id),
                      id: doc.id,
                      data: data,
                    );
                  }),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        BusinessQuickActionsSection(
          title: "Quick Actions",
          actions: [
            BusinessQuickActionItem(
              label: "Add Pet",
              icon: Icons.pets,
              onTap: widget.onOpenPets,
            ),
            BusinessQuickActionItem(
              label: "Requests",
              icon: LucideIcons.heartHandshake,
              onTap: widget.onOpenRequests,
            ),
            BusinessQuickActionItem(
              label: "Settings",
              icon: LucideIcons.settings,
              onTap: widget.onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic> contact,
  ) {
    final name = profile['displayName'] ?? 'Adoption Center';

    final description = profile['description'] ?? "No description yet";

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: AppTheme.h3(weight: FontWeight.w800)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(description, style: AppTheme.body(color: AppTheme.muted)),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,

            runSpacing: 8,

            children: [
              _chip("📞 ${contact['phone'] ?? '-'}"),

              _chip("📍 ${contact['city'] ?? '-'}"),

              _chip("📍 ${contact['district'] ?? '-'}"),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,

      borderRadius: BorderRadius.circular(16),

      border: Border.all(color: Colors.black12),

      boxShadow: AppTheme.cardShadow(opacity: 0.06),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: _cardDecoration(),

      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withOpacity(0.08),

        borderRadius: BorderRadius.circular(10),
      ),

      child: Text(
        text,

        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}

class _AdoptionRequestItem extends StatefulWidget {
  final String id;

  final Map<String, dynamic> data;

  const _AdoptionRequestItem({super.key, required this.id, required this.data});

  @override
  State<_AdoptionRequestItem> createState() => _AdoptionRequestItemState();
}

class _AdoptionRequestItemState extends State<_AdoptionRequestItem> {
  late final Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();

    final requesterId = (widget.data['requesterId'] ?? '').toString();

    final targetId = (widget.data['targetId'] ?? '').toString();

    _future = Future.wait([
      FirebaseFirestore.instance
          .collection('adoption_pets')
          .doc(targetId)
          .get(),

      FirebaseFirestore.instance.collection('users').doc(requesterId).get(),

      FirebaseFirestore.instance
          .collection('businesses')
          .doc(requesterId)
          .get(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.data['status'] ?? 'pending').toString();

    final requesterId = (widget.data['requesterId'] ?? '').toString();

    final targetId = (widget.data['targetId'] ?? '').toString();

    debugPrint('🐾 REQUEST DATA = ${widget.data}');

    debugPrint('🐾 REQUESTER ID = $requesterId');

    debugPrint('🐾 TARGET ID = $targetId');

    final ts = widget.data['createdAt'];

    final date = ts is Timestamp ? ts.toDate() : null;

    final dateLabel = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.year}';

    return FutureBuilder<List<dynamic>>(
      future: _future,

      builder: (context, snapshot) {
        debugPrint('🐾 FUTURE HAS DATA = ${snapshot.hasData}');

        String petName = "Pet";
        String breed = "";
        String requester = "User";

        if (snapshot.hasData) {
          final petSnap = snapshot.data![0] as DocumentSnapshot;

          final userSnap = snapshot.data![1] as DocumentSnapshot;

          if (petSnap.exists && petSnap.data() != null) {
            final pet = petSnap.data() as Map<String, dynamic>;

            petName = (pet['name'] ?? 'Pet').toString();

            breed = (pet['breed'] ?? '').toString();
          }

          if (userSnap.exists && userSnap.data() != null) {
            final userSnap = snapshot.data![1] as DocumentSnapshot;

            final businessSnap = snapshot.data![2] as DocumentSnapshot;

            debugPrint('🐾 USER EXISTS = ${userSnap.exists}');

            debugPrint('🐾 BUSINESS EXISTS = ${businessSnap.exists}');

            debugPrint('🐾 USER DATA = ${userSnap.data()}');

            debugPrint('🐾 BUSINESS DATA = ${businessSnap.data()}');

            if (userSnap.exists && userSnap.data() != null) {
              final user = userSnap.data() as Map<String, dynamic>;

              requester =
                  (user['displayName'] ??
                          user['name'] ??
                          user['username'] ??
                          '')
                      .toString();
            }

            if ((requester.isEmpty || requester == 'User') &&
                businessSnap.exists &&
                businessSnap.data() != null) {
              final business = businessSnap.data() as Map<String, dynamic>;

              final profile =
                  (business['profile'] as Map?)?.cast<String, dynamic>() ?? {};

              requester =
                  (profile['displayName'] ?? profile['businessName'] ?? '')
                      .toString();
            }

            if (requester.isEmpty) {
              requester = (widget.data['requesterName'] ?? 'User').toString();
            }
          }
        }

        return GestureDetector(
          onTap: () {
            final appState = context.read<AppState>();

            appState.setInitialAdoptionRequestId(widget.id);

            appState.setCurrentTab(NavTab.profile);

            appState.openProfileSubPage(ProfileSubPage.adoptionInbox);
          },

          child: Container(
            margin: const EdgeInsets.only(bottom: 12),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(
                color: const Color(0xFF9E1B4F).withOpacity(.10),
              ),

              boxShadow: AppTheme.cardShadow(opacity: .06),
            ),

            child: Padding(
              padding: const EdgeInsets.all(14),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,

                        decoration: BoxDecoration(
                          color: const Color(0xFF9E1B4F).withOpacity(.08),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: const Icon(
                          LucideIcons.heartHandshake,

                          color: Color(0xFF9E1B4F),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              petName,

                              style: AppTheme.body(
                                color: AppTheme.textDark,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),

                            const SizedBox(height: 6),

                            Row(
                              children: [
                                _statusPill(status),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: Text(
                                    requester,

                                    overflow: TextOverflow.ellipsis,

                                    style: AppTheme.caption(
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "$breed • $dateLabel",

                              style: AppTheme.caption(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    AppLocalizations.of(context)!.tapForMoreDetails,

                    style: AppTheme.caption(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusPill(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;

      case 'completed':
        color = Colors.purple;
        break;

      case 'rejected':
        color = Colors.red;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: color.withOpacity(0.12),

        borderRadius: BorderRadius.circular(999),
      ),

      child: Text(
        status.toUpperCase(),

        style: TextStyle(
          color: color,

          fontWeight: FontWeight.w700,

          fontSize: 10,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTheme.h2());
  }
}

class _KpiCard extends StatelessWidget {
  final String title;

  final String value;

  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.15)),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),

            const SizedBox(height: 8),

            Text(value, style: AppTheme.h2(weight: FontWeight.w800)),

            Text(title, style: AppTheme.caption()),
          ],
        ),
      ),
    );
  }
}
