import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';

class VetDashboardAppointmentsTab extends StatefulWidget {
  final String businessId;
  final String collectionName;
  final String updateFunctionName;
  final String cancelledByBusinessStatus;
  final String businessDebugLabel;

  const VetDashboardAppointmentsTab({
    super.key,
    required this.businessId,
    this.collectionName = 'vet_appointments',
    this.updateFunctionName = 'updateVetAppointmentStatus',
    this.cancelledByBusinessStatus = 'cancelled_by_vet',
    this.businessDebugLabel = 'vet',
  });

  @override
  State<VetDashboardAppointmentsTab> createState() =>
      _VetDashboardAppointmentsTabState();
}

class _VetDashboardAppointmentsTabState
    extends State<VetDashboardAppointmentsTab> {
  String? _processingId;

  List<QueryDocumentSnapshot> _docs = [];

  String? _highlightedAppointmentId;
  final ScrollController _scrollController = ScrollController();
  AppState? _appState;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appState = context.read<AppState>();
      _appState?.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    final appState = context.read<AppState>();
    final targetId = appState.openAppointmentId;

    debugPrint("👀 openAppointmentId = $targetId");

    if (targetId == null) return;

    // 🔥 این مهمه
    if (_docs.isEmpty) {
      debugPrint("⏳ WAITING FOR DOCS...");
      return;
    }

    debugPrint("🚀 AUTO OPEN APPOINTMENT → $targetId");

    // 🔥 تا مطمئن نشیم UI آماده‌ست
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToAppointment(targetId);
      appState.consumeOpenAppointment();
    });
  }

  Widget _buildAppointmentDetail(Map<String, dynamic> data, String id) {
    final status = (data['status'] ?? 'pending') as String;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['petName'] ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text("Service: ${data['serviceTitle'] ?? ''}"),
          Text("Status: ${_statusLabel(status)}"),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // accept logic بعداً
                  },
                  child: const Text("Accept"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // reject logic بعداً
                  },
                  child: const Text("Reject"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'awaiting_payment':
        return 'Awaiting payment';
      case 'confirmed':
        return 'Confirmed';
      case 'confirmed_paid':
        return 'Confirmed & Paid';
      case 'payment_expired':
        return 'Payment expired';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'cancelled_by_user':
        return 'Cancelled by user';
      case 'cancelled_by_vet':
        return 'Cancelled by vet';
      case 'cancelled_by_groomy':
        return 'Cancelled by groomy';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  void _scrollToAppointment(String id) {
    final index = _docs.indexWhere((d) => d.id == id); // 👈 FIX

    if (index == -1) {
      debugPrint("❌ Appointment not found in list");
      return;
    }

    debugPrint("✅ FOUND index = $index");

    setState(() {
      _highlightedAppointmentId = id;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        index * 120,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    // remove highlight after 2 sec
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedAppointmentId = null;
        });
      }
    });
  }

  void _handleAutoOpen(AppState appState) {
    final targetId = appState.openAppointmentId;

    if (targetId == null) return;

    _scrollToAppointment(targetId); // ✅
    appState.consumeOpenAppointment();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collectionName)
          .where('businessId', isEqualTo: widget.businessId)
          .orderBy('scheduledAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('No appointments yet'));
        }
        _docs = snap.data!.docs;

        return ListView.builder(
          controller: _scrollController, // 👈 اینجا اضافه کن
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final doc = snap.data!.docs[i];
            final isHighlighted = doc.id == _highlightedAppointmentId;
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'pending') as String;

            final ts = data['scheduledAt'];
            final dt = ts is Timestamp ? ts.toDate() : null;

            String dateText = '';
            if (dt != null) {
              dateText =
                  "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} • "
                  "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Colors.yellow.withOpacity(0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHighlighted ? Colors.orange : Colors.black12,
                  width: isHighlighted ? 2 : 1,
                ),
              ),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// SERVICE TITLE
                      Text(
                        data['serviceTitle'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 6),

                      /// PET NAME
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                data['petType'] == 'cat'
                                    ? Icons.pets
                                    : data['petType'] == 'bird'
                                    ? Icons.flutter_dash
                                    : Icons.pets,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${data['petName'] ?? data['dogName'] ?? ''} • ${data['petType'] ?? 'dog'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Breed: ${data['petBreed'] ?? '-'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "Age: ${data['petAge'] ?? '-'}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      /// DATE
                      Text(dateText),

                      const SizedBox(height: 8),

                      /// STATUS CHIP
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ACTIONS
                      _buildActions(doc, status, data),
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

  /// =========================
  /// ACTION BUILDER
  /// =========================
  Widget _buildActions(
    DocumentSnapshot doc,
    String status,
    Map<String, dynamic> data,
  ) {
    if (status == 'pending') {
      final targetStatus = _approvalTargetStatus(data);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              _action(doc, targetStatus, 'Approve', data: data),
              _action(doc, 'rejected', 'Reject'),
            ],
          ),
        ],
      );
    }

    if (status == 'confirmed' || status == 'confirmed_paid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              _action(doc, 'completed', 'Complete'),
              _action(doc, widget.cancelledByBusinessStatus, 'Cancel'),
            ],
          ),
        ],
      );
    }

    return Text(
      "Already ${_statusLabel(status)}",
      style: const TextStyle(color: Colors.grey),
    );
  }

  /// =========================
  /// ACTION BUTTON
  /// =========================
  String _approvalTargetStatus(Map<String, dynamic> data) {
    final rawPrice = data['servicePrice'] ?? data['price'];
    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
    final requiresPayment = data['serviceRequiresPayment'] == true || price > 0;
    final targetStatus = requiresPayment ? 'awaiting_payment' : 'confirmed';
    debugPrint(
      '${widget.businessDebugLabel} PAYMENT CTA DECISION → '
      'serviceRequiresPayment=${data['serviceRequiresPayment']} '
      'price=$price targetStatus=$targetStatus',
    );
    return targetStatus;
  }

  Widget _action(
    DocumentSnapshot doc,
    String newStatus,
    String label, {
    Map<String, dynamic>? data,
  }) {
    final isLoading = _processingId == doc.id;

    return OutlinedButton(
      onPressed: isLoading
          ? null
          : () async {
              setState(() => _processingId = doc.id);
              debugPrint(
                '🩺 PAYMENT CTA DECISION → '
                'appointmentId=${doc.id} targetStatus=$newStatus '
                'serviceRequiresPayment=${data?['serviceRequiresPayment']} '
                'price=${data?['price'] ?? data?['servicePrice'] ?? 'n/a'}',
              );

              try {
                await FirebaseFunctions.instanceFor(region: 'europe-west3')
                    .httpsCallable(widget.updateFunctionName)
                    .call({'appointmentId': doc.id, 'newStatus': newStatus});
              } catch (e) {
                debugPrint("❌ function error: $e");

                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("$e")));
                }
              } finally {
                if (mounted) {
                  setState(() => _processingId = null);
                }
              }
            },
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  /// =========================
  /// STATUS COLOR
  /// =========================
  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
        return Colors.green;
      case 'awaiting_payment':
        return Colors.deepOrange;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'cancelled_by_vet':
      case 'cancelled_by_groomy':
        return Colors.grey;
      case 'cancelled_by_user':
        return Colors.grey;
      case 'expired':
        return Colors.black45;
      case 'confirmed_paid':
        return Colors.green;
      case 'payment_expired':
        return Colors.grey;
      default:
        return Colors.orange; // pending
    }
  }
}
