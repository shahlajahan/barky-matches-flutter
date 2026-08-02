import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/ui/vet/edit_vet_profile_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_schedule_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_patients_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_settings_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_gallery_management_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/widgets/business_quick_actions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class VetDashboardOverviewTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const VetDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<VetDashboardOverviewTab> createState() =>
      _VetDashboardOverviewTabState();
}

class _VetDashboardOverviewTabState extends State<VetDashboardOverviewTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _appointmentsStream;
  late final Stream<QuerySnapshot> _servicesStream;

  String get businessId => widget.businessId;
  Map<String, dynamic> get businessData => widget.businessData;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _appointmentsStream = FirebaseFirestore.instance
        .collection('vet_appointments')
        .where('businessId', isEqualTo: widget.businessId)
        .orderBy('scheduledAt', descending: true)
        .snapshots();
    _servicesStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('services')
        .orderBy('createdAt', descending: true)
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
    //debugPrint('📄 Overview build ${identityHashCode(this)}');
    final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});
    final contact = Map<String, dynamic>.from(businessData['contact'] ?? {});

    return ListView(
      controller: _scrollController,
      key: const PageStorageKey('vet_dashboard_overview_scroll'),
      cacheExtent: 5000,
      padding: const EdgeInsets.all(16),
      children: [
        /// ================= PROFILE (ONLY ONCE) =================
        _SectionTitle("Clinic Profile"),
        const SizedBox(height: 10),
        _profileCard(context, profile, contact),

        const SizedBox(height: 20),

        /// ================= KPI =================

        /// ================= APPOINTMENTS =================
        _SectionTitle("Recent Appointments"),
        const SizedBox(height: 10),

        _KeepAliveWrapper(
          child: RepaintBoundary(
            child: StreamBuilder<QuerySnapshot>(
              stream: _appointmentsStream,
              builder: (context, snapshot) {
                debugPrint("🟡 APPOINTMENT STREAM BUILD");
                debugPrint("🟡 businessId = $businessId");
                debugPrint("🟡 state = ${snapshot.connectionState}");
                debugPrint("🟡 hasData = ${snapshot.hasData}");
                debugPrint("🟡 hasError = ${snapshot.hasError}");
                debugPrint("🟡 error = ${snapshot.error}");
                debugPrint("🟡 docs = ${snapshot.data?.docs.length}");

                if (snapshot.hasError) {
                  return _emptyBox("Appointment error: ${snapshot.error}");
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _emptyBox("Loading appointments...");
                }

                if (!snapshot.hasData) {
                  return _emptyBox("No appointment data");
                }

                final docs = snapshot.data!.docs.toList(); // 🔥 مهم (mutable)
                int total = docs.length;

                int pendingCount = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['status'] == 'pending';
                }).length;

                int confirmedCount = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['status'] == 'confirmed';
                }).length;

                int completedCount = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['status'] == 'completed';
                }).length;
                // 🔥 SORT حرفه‌ای (pending اول + جدیدترین بالا)
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aStatus = aData['status'] ?? '';
                  final bStatus = bData['status'] ?? '';

                  // ✅ pending بیاد بالا
                  if (aStatus == 'pending' && bStatus != 'pending') return -1;
                  if (aStatus != 'pending' && bStatus == 'pending') return 1;

                  // ✅ بعدش بر اساس زمان
                  final aTs =
                      aData['scheduledAt'] ?? aData['scheduledDateTime'];
                  final bTs =
                      bData['scheduledAt'] ?? bData['scheduledDateTime'];

                  final aTime = aTs is Timestamp ? aTs.toDate() : null;
                  final bTime = bTs is Timestamp ? bTs.toDate() : null;

                  if (aTime == null || bTime == null) return 0;

                  return bTime.compareTo(aTime); // newest first
                });

                if (docs.isEmpty) {
                  return _emptyBox("No appointments yet");
                }

                // 🔥 1. جدا کردن pending

                final pending = docs
                    .where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['status'] == 'pending';
                    })
                    .take(3)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ================= KPI (NEW) =================
                    Row(
                      children: [
                        _KpiCard(
                          title: "Total",
                          value: "$total",
                          icon: LucideIcons.calendar,
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
                          title: "Confirmed",
                          value: "$confirmedCount",
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

                    /// ================= PENDING =================
                    _SectionTitle("Pending Requests"),
                    const SizedBox(height: 8),

                    if (pending.isEmpty)
                      _emptyBox("No pending requests")
                    else
                      ...pending.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return RepaintBoundary(
                          child: _AppointmentItem(
                            key: ValueKey(doc.id),
                            id: doc.id,
                            data: data,
                          ),
                        );
                      }),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                )!.openAppointmentsTab,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)!.viewAllAppointments,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        /// ================= SERVICES =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle("Services"),
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
        _KeepAliveWrapper(
          child: RepaintBoundary(
            child: StreamBuilder<QuerySnapshot>(
              stream: _servicesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                    '❌ VET SERVICES STREAM ERROR → '
                    'businessId=$businessId error=${snapshot.error}',
                  );
                  return _servicesErrorState();
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _ServicesLoadingState();
                }

                if (!snapshot.hasData) {
                  return const _ServicesLoadingState();
                }

                final docs = snapshot.data!.docs;
                final newServices = docs
                    .map(
                      (doc) => ((doc.data() as Map)['title'] ?? '').toString(),
                    )
                    .where((title) => title.isNotEmpty)
                    .toList();
                final appState = context.read<AppState>();

                if (!listEquals(appState.existingServices, newServices)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      appState.setExistingServices(newServices);
                    }
                  });
                }

                if (docs.isEmpty) {
                  return const _ServicesEmptyState();
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _serviceItem(context, doc.id, data);
                  }).toList(),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        BusinessQuickActionsSection(
          title: "Quick Actions",
          actions: [
            BusinessQuickActionItem(
              label: "Schedule",
              icon: LucideIcons.calendar,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VetSchedulePage(businessId: businessId),
                  ),
                );
              },
            ),
            BusinessQuickActionItem(
              label: "Patients",
              icon: LucideIcons.users,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VetPatientsPage(businessId: businessId),
                  ),
                );
              },
            ),
            BusinessQuickActionItem(
              label: "Gallery",
              icon: LucideIcons.image,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VetGalleryManagementPage(businessId: businessId),
                  ),
                );
              },
            ),
            BusinessQuickActionItem(
              label: "Settings",
              icon: LucideIcons.settings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VetSettingsPage(businessId: businessId),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _servicesErrorState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              color: AppTheme.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.servicesCouldNotBeLoaded,
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.checkConnectionTryAgain,
                  style: AppTheme.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceItem(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    // 🔥 اینجا درستشه
    final price = data['price']?.toString();
    final duration = data['duration']?.toString();

    String priceText;
    if (price == null) {
      priceText = "Price on request";
    } else {
      priceText = "₺$price";
    }

    String durationText;
    if (duration == null || duration.toString().isEmpty) {
      durationText = "Flexible duration";
    } else {
      durationText = duration.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: AppLocalizations.of(context)!.editServiceTooltip,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: () {
                  context.read<AppState>().openAddServiceDetail(
                    data['title']?.toString() ?? '',
                    serviceId: id,
                    existingData: data,
                  );
                },
                icon: const Icon(LucideIcons.edit2, size: 19),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.deleteServiceTooltip,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: () => _deleteService(context, businessId, id),
                icon: const Icon(LucideIcons.trash2, size: 19),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ✅ اینجا فقط Text
          Text(
            "$priceText • $durationText",
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

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic> contact,
  ) {
    final name = profile['displayName'] ?? 'Clinic';
    final description =
        profile['description'] ?? profile['bio'] ?? "No description yet";
    debugPrint(
      '🩺 VET BUSINESS MAP → source=VetDashboardOverview '
      'businessId=$businessId displayName=$name '
      'descriptionLength=${description.toString().length}',
    );

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
                          EditVetProfilePage(businessId: businessId),
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

  /// ================= UI HELPERS =================

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

class _AppointmentItem extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _AppointmentItem({super.key, required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    debugPrint("🧩 RENDER: ${data['dogName']} - ${data['status']}");
    final status = data['status'] ?? 'pending';

    final petName = data['petName'] ?? data['dogName'] ?? '';
    final petType = data['petType'] ?? 'dog';
    final petBreed = data['petBreed'] ?? '-';
    final petAge = data['petAge'] ?? '-';
    // 🔥 SERVICE (پشتیبانی از هر دو ساختار)
    String serviceTitle = '';
    String price = '';

    if (data['service'] != null) {
      final service = data['service'] as Map<String, dynamic>;
      serviceTitle = service['title'] ?? '';
      price = service['price']?.toString() ?? '';
    } else {
      serviceTitle = data['serviceTitle'] ?? '';
      price = data['price']?.toString() ?? '';
    }

    // 🔥 TIME (پشتیبانی از هر دو)
    final ts = data['scheduledDateTime'] ?? data['scheduledAt'];

    final dt = ts is Timestamp ? ts.toDate() : null;

    String dateText = '';
    if (dt != null) {
      dateText =
          "${dt.year}-${dt.month}-${dt.day} • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }

    Color statusColor;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$petName • $petType",
                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.breedValue(petBreed),
                      style: AppTheme.caption(),
                    ),
                    Text(
                      AppLocalizations.of(context)!.ageValue(petAge),
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// SERVICE
          Text(
            "$serviceTitle • ₺$price",
            style: AppTheme.body(color: AppTheme.muted),
          ),

          const SizedBox(height: 4),

          /// DATE
          Text(dateText, style: AppTheme.caption()),

          const SizedBox(height: 10),

          /// ACTIONS
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateAppointmentStatus(
                      context,
                      id,
                      _approvalTargetStatus(data),
                      data,
                    ),
                    child: Text(AppLocalizations.of(context)!.accept),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _updateAppointmentStatus(context, id, 'rejected', data),
                    child: Text(AppLocalizations.of(context)!.reject),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                AppLocalizations.of(
                  context,
                )!.alreadyStatus(status.toUpperCase()),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _updateAppointmentStatus(
    BuildContext context,
    String id,
    String newStatus,
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '🩺 PAYMENT CTA DECISION → '
      'appointmentId=$id targetStatus=$newStatus '
      'serviceRequiresPayment=${data['serviceRequiresPayment']} '
      'price=${data['price'] ?? data['servicePrice'] ?? 'n/a'}',
    );
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateVetAppointmentStatus');

      await callable.call({'appointmentId': id, 'newStatus': newStatus});

      debugPrint("✅ FUNCTION CALLED → $newStatus");

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'confirmed'
                ? "Appointment accepted"
                : "Appointment rejected",
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ FUNCTION ERROR: $e");

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.updateFailed('$e')),
        ),
      );
    }
  }

  static String _approvalTargetStatus(Map<String, dynamic> data) {
    final rawPrice = data['servicePrice'] ?? data['price'];
    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    final requiresPayment = data['serviceRequiresPayment'] == true || price > 0;
    return requiresPayment ? 'awaiting_payment' : 'confirmed';
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

class _ServicesLoadingState extends StatelessWidget {
  const _ServicesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 78,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDE6E9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: index == 0 ? 132 : 164,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE8EA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 96,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDEF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 72,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDEF),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicesEmptyState extends StatelessWidget {
  const _ServicesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E1E4)),
        boxShadow: AppTheme.cardShadow(opacity: 0.035),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.card.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.stethoscope,
              color: AppTheme.card,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.noServicesAddedYet,
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.addFirstServiceDescription,
                  style: AppTheme.caption().copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= COMPONENTS =================

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
          border: Border.all(
            color: const Color(0xFF9E1B4F).withValues(alpha: 0.15),
          ),
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
