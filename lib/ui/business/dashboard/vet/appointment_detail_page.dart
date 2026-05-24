import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';

class AppointmentDetailPage extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailPage({
    super.key,
    required this.appointmentId,
  });

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointmentDetailTitle),
        backgroundColor: const Color(0xFF9E1B4F),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vet_appointments')
            .doc(widget.appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return Center(child: Text(l10n.appointmentNotFound));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final petName = data['petName'] ?? data['dogName'] ?? '-';
          final service = data['serviceTitle'] ?? '-';
          final status = (data['status'] ?? '-').toString();
          final paymentStatus = (data['paymentStatus'] ?? 'unpaid').toString();
          final refundStatus = (data['refundStatus'] ?? '').toString();
          final refundRequired = data['refundRequired'] == true;
          final refundLabel = AppointmentStatusUtils.refundStatusLabel(
            refundRequired: refundRequired,
            refundStatus: refundStatus,
            l10n: l10n,
          );
          final price = data['price'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text("${l10n.petLabel}: $petName"),
                Text(
                  "${l10n.statusLabel}: ${AppointmentStatusUtils.statusLabel(status, l10n)}",
                ),
                Text(
                  "${l10n.paymentLabel}: ${AppointmentStatusUtils.paymentStatusLabel(paymentStatus, l10n)}",
                ),
                if (refundLabel.isNotEmpty)
                  Text("${l10n.refundResultLabel}: $refundLabel"),
                Text("${l10n.priceLabel}: ₺$price"),

                const SizedBox(height: 24),

                if (paymentStatus != "paid")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/appointmentPayment',
                          arguments: widget.appointmentId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E1B4F),
                      ),
                      child: Text(l10n.goToPaymentButton),
                    ),
                  ),

                if (status == "confirmed_paid") ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await FirebaseFirestore.instance
                            .collection('vet_appointments')
                            .doc(widget.appointmentId)
                            .update({
                          "status": "completed",
                        });

                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.markedAsCompletedSnack)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(l10n.markAsCompletedButton),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
