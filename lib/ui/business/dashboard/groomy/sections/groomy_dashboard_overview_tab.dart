import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/business/groomy/edit_groomy_profile_page.dart';
import 'package:barky_matches_fixed/ui/business/groomy/groomy_appointment_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_schedule_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_clients_page.dart';

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
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _revenueStream;
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

  Map<String, dynamic>? get _workingHoursMap {
    final raw =
        _groomyData['workingHoursMap'] ??
        _groomyData['workingHours'] ??
        _rootData['workingHours'];

    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) return {'hours': raw};
    return null;
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
    _revenueStream = FirebaseFirestore.instance
        .collection('groomy_appointments')
        .where('businessId', isEqualTo: widget.businessId)
        .snapshots(includeMetadataChanges: false);
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

          _SectionTitle('Revenue'),
          const SizedBox(height: 10),
          _KeepAliveWrapper(
            child: RepaintBoundary(child: _buildRevenueCard(context)),
          ),
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
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _emptyBox('Manage your grooming services from here'),
          const SizedBox(height: 24),

          _SectionTitle('Quick Actions'),
          const SizedBox(height: 10),
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

  Widget _buildRevenueCard(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '💰 GROOMY REVENUE QUERY → authUid=${FirebaseAuth.instance.currentUser?.uid ?? "NULL"} '
        'businessId=$businessId path=groomy_appointments where businessId==$businessId',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _revenueStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
              '💰 GROOMY REVENUE ERROR → businessId=$businessId error=${snapshot.error}',
            );
          }
          return _emptyBox('Revenue error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final paidDocs = docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          return status == 'confirmed_paid' || status == 'completed';
        }).toList();

        if (paidDocs.isEmpty) {
          return _emptyBox('No revenue yet');
        }

        double netRevenue = 0;
        double grossSales = 0;
        double commissionTotal = 0;
        double adjustmentsTotal = 0;

        for (final doc in paidDocs) {
          final data = doc.data();
          final financial = Map<String, dynamic>.from(data['financial'] ?? {});
          final pricing = Map<String, dynamic>.from(data['pricing'] ?? {});

          final gross = _moneyValue(
            pricing['total'] ??
                pricing['grandTotal'] ??
                data['paymentAmount'] ??
                data['servicePrice'] ??
                data['price'] ??
                data['totalPrice'],
          );
          final commission = _moneyValue(
            financial['platformCommissionAmount'] ??
                financial['commissionAmount'] ??
                data['platformFee'],
          );
          final explicitNet =
              financial['groomyNetAmount'] ?? financial['netAmount'];
          final net = explicitNet == null
              ? gross - commission
              : _moneyValue(explicitNet);

          grossSales += gross;
          commissionTotal += commission;
          netRevenue += net;

          if (kDebugMode) {
            debugPrint(
              '💸 GROOMY APPOINTMENT REVENUE → appointmentId=${doc.id} '
              'gross=$gross commission=$commission net=$net',
            );
          }
        }

        final appointmentCount = paidDocs.length;
        final averageTicket = appointmentCount == 0
            ? 0.0
            : grossSales / appointmentCount;

        if (kDebugMode) {
          debugPrint(
            '💰 GROOMY FINAL REVENUE → businessId=$businessId '
            'net=$netRevenue gross=$grossSales commission=$commissionTotal '
            'appointments=$appointmentCount averageTicket=$averageTicket',
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Net Revenue',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                '₺${netRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'After platform commission',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _revenueRow('Gross Sales', grossSales),
              _revenueRow('Platform Fee', -commissionTotal),
              _revenueRow('Adjustments', -adjustmentsTotal),
              const SizedBox(height: 14),
              Row(
                children: [
                  _revenueKpi(
                    label: 'Paid Appointments',
                    value: appointmentCount.toString(),
                  ),
                  const SizedBox(width: 10),
                  _revenueKpi(
                    label: 'Average Ticket',
                    value: '₺${averageTicket.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
                  Text('Recent Appointments', style: AppTheme.h2()),
                  const SizedBox(height: 4),
                  Text(
                    'Latest grooming requests and sessions',
                    style: AppTheme.caption(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onOpenAppointments,
              child: const Text('View All'),
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
                  return Text('Appointment error: ${snapshot.error}');
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
                          'No grooming appointments yet',
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
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            'Schedule',
            LucideIcons.calendar,
            onTap: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (_) => GroomySchedulePage(businessId: businessId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            'Clients',

            LucideIcons.users,

            onTap: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (_) => GroomyClientsPage(businessId: businessId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            'Gallery',
            LucideIcons.image,
            onTap: widget.onOpenGallery,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            'Settings',
            LucideIcons.settings,
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
                label: const Text('Edit'),
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
        title: const Text('Delete Service'),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service deleted')));
    } catch (e) {
      debugPrint('❌ deleteService error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delete failed')));
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

  double _moneyValue(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  Widget _revenueRow(String title, double value) {
    final isNegative = value < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            '${isNegative ? '-' : ''}₺${value.abs().toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _revenueKpi({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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

  BusinessCardData _businessCardData() {
    final profile = _profile;
    final contact = _contact;
    final rawData = _rootData;
    final name =
        (profile['displayName'] ??
                profile['businessName'] ??
                _groomyData['salonName'] ??
                _groomyData['businessName'] ??
                'Groomy Salon')
            .toString();
    final specialties = <String>[
      ..._stringList(_groomyData['specialties']),
      ..._stringList(
        (_groomyData['services'] is Map)
            ? (_groomyData['services'] as Map)['offeredServices']
            : null,
      ),
    ];

    return BusinessCardData(
      id: businessId,
      name: name,
      city: (contact['city'] ?? '').toString(),
      district: (contact['district'] ?? '').toString(),
      address: (contact['address'] ?? '').toString(),
      specialties: specialties,
      services: _fallbackServices()
          .map((service) => service['title']?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      phone: (contact['phone'] ?? _groomyData['phone'] ?? '').toString(),
      whatsapp: (contact['whatsapp'] ?? _groomyData['whatsapp'] ?? '')
          .toString(),
      rating: _moneyValue(_rootData['rating']),
      reviewsCount: (_rootData['reviewsCount'] as num?)?.toInt(),
      workingHours: _workingHoursMap,
      description:
          (profile['description'] ??
                  profile['bio'] ??
                  _groomyData['description'] ??
                  '')
              .toString(),
      isPartner: true,
      isVerified: _rootData['isVerified'] == true,
      is24h: _rootData['is24h'] == true,
      isEmergency: _rootData['isEmergency'] == true,
      type: BusinessType.groomer,
      instagram: (profile['instagram'] ?? _groomyData['instagram'] ?? '')
          .toString(),
      website: (profile['website'] ?? _groomyData['website'] ?? '').toString(),
      logoUrl: (profile['logoUrl'] ?? _groomyData['logoUrl'] ?? '').toString(),
      rawData: rawData,
      data: rawData,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').toList();
    }
    final text = value?.toString() ?? '';
    return text.trim().isEmpty ? <String>[] : <String>[text];
  }

  List<Map<String, dynamic>> _fallbackServices() {
    final servicesData = _groomyData['services'];
    List<String> titles = [];

    if (servicesData is Map && servicesData['offeredServices'] is List) {
      titles = List<String>.from(servicesData['offeredServices']);
    } else if (servicesData is List) {
      titles = servicesData.map((item) => item.toString()).toList();
    } else if (_rootData['services'] is List) {
      titles = List<String>.from(_rootData['services'] as List);
    }

    if (titles.isEmpty) {
      titles = const ['Full Grooming', 'Bath & Dry', 'Nail Trimming'];
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

class _ActionBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionBtn(this.text, this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF9E1B4F)),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    );
  }
}
