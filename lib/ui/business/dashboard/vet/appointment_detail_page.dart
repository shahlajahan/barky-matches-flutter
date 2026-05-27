import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';

class AppointmentDetailPage extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailPage({super.key, required this.appointmentId});

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

          return SingleChildScrollView(
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

                _preVisitFormSection(data),

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
                            .update({"status": "completed"});

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

  Widget _preVisitFormSection(Map<String, dynamic> data) {
    final answers = _asMap(data['preVisitAnswers']);
    final snapshot = _asMap(data['preVisitSnapshot']);
    final questions = _listOfMaps(snapshot['questions']);
    final legacyAnswers = _listOfMaps(_asMap(data['preVisitForm'])['answers']);

    if (answers.isEmpty && legacyAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Pre-visit form',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: questions.isNotEmpty
                ? questions.map((question) {
                    final questionId = (question['id'] ?? '').toString();
                    final questionText = (question['question'] ?? '')
                        .toString();
                    final value = _formatAnswer(answers[questionId]);

                    return _answerBlock(questionText, value);
                  }).toList()
                : legacyAnswers.map((answer) {
                    final question = (answer['question'] ?? '').toString();
                    final value = _formatAnswer(answer['answer']);
                    return _answerBlock(question, value);
                  }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _answerBlock(String question, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _formatAnswer(Object? value) {
  if (value is List) return value.map((e) => e.toString()).join(', ');
  if (value is bool) return value ? 'Yes' : 'No';
  return (value ?? '').toString();
}
