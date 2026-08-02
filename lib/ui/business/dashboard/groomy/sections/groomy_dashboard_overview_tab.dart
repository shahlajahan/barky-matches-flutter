import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/groomy/edit_groomy_profile_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_schedule_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_clients_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/widgets/business_quick_actions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class GroomyDashboardOverviewTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenGallery;

  const GroomyDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
    this.onOpenAppointments,
    this.onOpenGallery,
  });

  @override
  State<GroomyDashboardOverviewTab> createState() =>
      _GroomyDashboardOverviewTabState();
}

class _GroomyDashboardOverviewTabState extends State<GroomyDashboardOverviewTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream;

  @override
  bool get wantKeepAlive => true;

  String get businessId => widget.businessId;

  Map<String, dynamic> get _rootData => widget.businessData;

  Map<String, dynamic> get _profile {
    return Map<String, dynamic>.from(_rootData['profile'] ?? {});
  }

  Map<String, dynamic> get _contact {
    return Map<String, dynamic>.from(_rootData['contact'] ?? {});
  }

  Map<String, dynamic> get _sectorData {
    return Map<String, dynamic>.from(_rootData['sectorData'] ?? {});
  }

  Map<String, dynamic> get _groomyData {
    return Map<String, dynamic>.from(
      _sectorData['groomy'] ??
          _sectorData['groomer'] ??
          _sectorData['grooming'] ??
          {},
    );
  }

  @override
  void initState() {
    super.initState();
    _appointmentsStream = FirebaseFirestore.instance
        .collection('groomy_appointments')
        .where('businessId', isEqualTo: widget.businessId)
        .orderBy('scheduledAt', descending: true)
        .limit(5)
        .snapshots();
    _servicesStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('services')
        .orderBy('sortOrder')
        .snapshots();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profile = Map<String, dynamic>.from(_profile);
    final contact = Map<String, dynamic>.from(_contact);

    return Container(
      color: AppTheme.bg,
      child: ListView(
        controller: _scrollController,
        key: const PageStorageKey('groomy_dashboard_overview_scroll'),
        cacheExtent: 5000,
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Groomy Profile'),
          const SizedBox(height: 10),
          _profileCard(context, profile, contact),
          const SizedBox(height: 20),

          _buildAppointmentsSection(context),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionTitle('Services'),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  context.read<AppState>().openAddService();
                },
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(AppLocalizations.of(context)!.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _emptyBox('Manage your grooming services from here'),
          const SizedBox(height: 24),

          _buildQuickActions(context),

          const SizedBox(height: 24),
          _SectionTitle('Your Services'),
          const SizedBox(height: 10),
          _KeepAliveWrapper(
            child: RepaintBoundary(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _servicesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return _emptyBox('No services yet');
                  }

                  final newServices = docs
                      .map((e) => (e.data())['title']?.toString() ?? '')
                      .where((title) => title.trim().isNotEmpty)
                      .toList();

                  final appState = context.read<AppState>();
                  if (!listEquals(appState.existingServices, newServices)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        appState.setExistingServices(newServices);
                      }
                    });
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      return _serviceItem(context, doc.id, data);
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.recentAppointments,
                    style: AppTheme.h2(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.latestGroomingRequests,
                    style: AppTheme.caption(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onOpenAppointments,
              child: Text(AppLocalizations.of(context)!.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _KeepAliveWrapper(
          child: RepaintBoundary(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _appointmentsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    AppLocalizations.of(
                      context,
                    )!.appointmentError('${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendar, color: Colors.black38),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.noGroomingAppointmentsYet,
                          style: AppTheme.body(color: AppTheme.muted),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    return _appointmentCard(context, doc.id, data);
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return BusinessQuickActionsSection(
      title: 'Quick Actions',
      actions: [
        BusinessQuickActionItem(
          label: 'Schedule',
          icon: LucideIcons.calendar,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroomySchedulePage(businessId: businessId),
              ),
            );
          },
        ),
        BusinessQuickActionItem(
          label: 'Clients',
          icon: LucideIcons.users,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroomyClientsPage(businessId: businessId),
              ),
            );
          },
        ),
        BusinessQuickActionItem(
          label: 'Gallery',
          icon: LucideIcons.image,
          onTap: widget.onOpenGallery,
        ),
        BusinessQuickActionItem(
          label: 'Settings',
          icon: LucideIcons.settings,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EditGroomyProfilePage(businessId: widget.businessId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic> contact,
  ) {
    final name =
        (profile['displayName'] ??
                profile['businessName'] ??
                _groomyData['salonName'] ??
                _groomyData['businessName'] ??
                'Groomy Salon')
            .toString();
    final description =
        (profile['description'] ??
                profile['bio'] ??
                _groomyData['description'] ??
                'No description yet')
            .toString();

    debugPrint(
      '🩺 GROOMY BUSINESS MAP → source=GroomyDashboardOverview '
      'businessId=$businessId displayName=$name '
      'descriptionLength=${description.length}',
    );

    final chips = <String>[
      if ((contact['phone'] ?? '').toString().isNotEmpty)
        '📞 ${contact['phone']}',
      if ((contact['city'] ?? '').toString().isNotEmpty)
        '📍 ${contact['city']}',
      if ((contact['district'] ?? '').toString().isNotEmpty)
        '📍 ${contact['district']}',
    ];

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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditGroomyProfilePage(businessId: businessId),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.edit2, size: 18),
                label: Text(AppLocalizations.of(context)!.edit),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: AppTheme.body(color: AppTheme.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [if (chips.isEmpty) _chip('Groomy'), ...chips.map(_chip)],
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final status = (data['status'] ?? 'pending').toString();
    final rawAmount =
        data['paymentAmount'] ??
        data['finalPrice'] ??
        data['servicePrice'] ??
        data['price'] ??
        data['totalPrice'] ??
        0;
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount.toString()) ?? 0;
    final services = data['services'] is List
        ? data['services'] as List
        : data['serviceIds'] is List
        ? data['serviceIds'] as List
        : data['serviceTitle'] != null
        ? [data['serviceTitle']]
        : const [];
    final ts = data['scheduledAt'] ?? data['scheduledDateTime'];
    final date = ts is Timestamp ? ts.toDate() : null;
    final dateLabel = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final title =
        (data['petName'] ?? data['dogName'] ?? data['clientName'] ?? 'Pet')
            .toString();
    final serviceTitle = (data['serviceTitle'] ?? data['serviceName'] ?? '')
        .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF9E1B4F).withValues(alpha: 0.10),
        ),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            widget.onOpenAppointments?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.scissors,
                    color: Color(0xFF9E1B4F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty
                            ? 'Appointment #${id.length > 6 ? id.substring(0, 6) : id}'
                            : title,
                        style: AppTheme.body(
                          color: AppTheme.textDark,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statusPill(status),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              serviceTitle.isEmpty
                                  ? '${services.length} service${services.length == 1 ? '' : 's'}'
                                  : serviceTitle,
                              style: AppTheme.caption(color: AppTheme.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dateLabel • ₺${amount.toStringAsFixed(0)}',
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status.toUpperCase().replaceAll('_', ' '),
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _serviceItem(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final title = (data['title'] ?? 'Untitled').toString();
    final priceText = _servicePriceText(data);
    final durationText = _serviceDurationText(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyMedium().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  context.read<AppState>().openAddServiceDetail(
                    title,
                    serviceId: id,
                    existingData: data,
                  );
                },
                child: const Icon(LucideIcons.edit2, size: 18),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _deleteService(context, businessId, id),
                child: const Icon(LucideIcons.trash2, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$priceText • $durationText',
            style: AppTheme.body(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(
    BuildContext context,
    String businessId,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteService),
        content: Text(AppLocalizations.of(context)!.deleteServiceConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('services')
          .doc(id)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.serviceDeleted)),
      );
    } catch (e) {
      debugPrint('❌ deleteService error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.deleteFailed)),
      );
    }
  }

  String _servicePriceText(Map<String, dynamic> service) {
    final raw = service['price'];
    if (raw == null || raw.toString().trim().isEmpty) {
      return 'Price on request';
    }
    return '₺${raw.toString()}';
  }

  String _serviceDurationText(Map<String, dynamic> service) {
    final raw = service['durationMin'] ?? service['duration'];
    if (raw == null || raw.toString().trim().isEmpty) {
      return 'Flexible duration';
    }
    return raw.toString();
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confirmed_paid':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'rejected':
      case 'cancelled_by_user':
      case 'cancelled_by_business':
        return Colors.red;
      case 'awaiting_payment':
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
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

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
