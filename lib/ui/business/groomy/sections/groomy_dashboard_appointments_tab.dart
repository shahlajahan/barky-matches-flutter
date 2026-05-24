import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class GroomyDashboardAppointmentsTab extends StatelessWidget {
  final String businessId;

  const GroomyDashboardAppointmentsTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groomy_appointments')
          .where('businessId', isEqualTo: businessId)
          .orderBy('scheduledAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint("✂️ GROOMY APPOINTMENTS TAB");

        if (snapshot.hasError) {
          return _centerText("Appointment error: ${snapshot.error}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _centerText("No grooming appointments yet");
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;

          final bData = b.data() as Map<String, dynamic>;

          final aStatus = aData['status'] ?? '';
          final bStatus = bData['status'] ?? '';

          if (aStatus == 'pending' && bStatus != 'pending') {
            return -1;
          }

          if (aStatus != 'pending' && bStatus == 'pending') {
            return 1;
          }

          final aTs = aData['scheduledAt'];
          final bTs = bData['scheduledAt'];

          final aTime = aTs is Timestamp ? aTs.toDate() : null;

          final bTime = bTs is Timestamp ? bTs.toDate() : null;

          if (aTime == null || bTime == null) {
            return 0;
          }

          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];

            final data = doc.data() as Map<String, dynamic>;

            return _appointmentCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _appointmentCard(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final status = data['status'] ?? 'pending';

    final petName = data['petName'] ?? '';

    final breed = data['petBreed'] ?? '-';

    final ownerName = data['username'] ?? '';

    final serviceTitle = data['serviceTitle'] ?? '';

    final rawPrice =
    data['price'] ??
    data['servicePrice'];

final price = rawPrice?.toString() ?? '0';

    final notes = data['notes'] ?? '';

    final ts = data['scheduledAt'];

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
      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.black12),

        boxShadow: AppTheme.cardShadow(opacity: 0.05),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,

                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(breed, style: AppTheme.caption()),

                    const SizedBox(height: 4),

                    Text(
                      ownerName,
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),

                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: Text(
                  status.toUpperCase(),

                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// SERVICE
          Row(
            children: [
              const Icon(
                LucideIcons.scissors,
                size: 16,
                color: Color(0xFF9E1B4F),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  "$serviceTitle • ₺$price",

                  style: AppTheme.body(color: AppTheme.muted),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// DATE
          Row(
            children: [
              const Icon(
                LucideIcons.calendar,
                size: 16,
                color: Color(0xFF9E1B4F),
              ),

              const SizedBox(width: 8),

              Text(dateText, style: AppTheme.caption()),
            ],
          ),

          if (notes.toString().trim().isNotEmpty)
            Column(
              children: [
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withOpacity(0.05),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Text(
                    notes,
                    style: AppTheme.body(color: AppTheme.muted),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),

          /// ACTIONS
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
  final rawPrice =
      data['price'] ??
      data['servicePrice'];

  final numericPrice = rawPrice is num
      ? rawPrice.toDouble()
      : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

  final nextStatus =
      numericPrice > 0
          ? 'awaiting_payment'
          : 'confirmed';

  _updateAppointmentStatus(
    context,
    appointmentId,
    nextStatus,
  );
},

                    child: const Text("Accept"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),

                    onPressed: () => _updateAppointmentStatus(
                      context,
                      appointmentId,
                      'rejected',
                    ),

                    child: const Text("Reject"),
                  ),
                ),
              ],
            )
          else if (status == 'confirmed')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateAppointmentStatus(
                  context,
                  appointmentId,
                  'completed',
                ),

                child: const Text("Mark Completed"),
              ),
            )
          else
            Center(
              child: Text(
                "Already ${status.toUpperCase()}",
                style: AppTheme.caption(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateAppointmentStatus(
  BuildContext context,
  String appointmentId,
  String newStatus,
) async {
  try {
    await FirebaseFunctions.instanceFor(
  region: 'europe-west3',
).httpsCallable(
  'updateGroomyAppointmentStatus',
).call({
  'appointmentId': appointmentId,
  'newStatus': newStatus,
});
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Appointment updated: $newStatus",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "❌ GROOMY UPDATE ERROR: $e",
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Update failed: $e",
        ),
      ),
    );
  }
}

  Widget _centerText(String text) {
    return Center(
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }
}
