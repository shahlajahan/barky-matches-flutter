import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailPage({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointment Detail"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vet_appointments')
            .doc(appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Appointment not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final petName = data['petName'] ?? data['dogName'] ?? '-';
          final service = data['serviceTitle'] ?? '-';
          final status = data['status'] ?? '-';
          final paymentStatus = data['paymentStatus'] ?? 'unpaid';
          final price = data['price'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// 🐾 TITLE
                Text(
                  service,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text("Pet: $petName"),
                Text("Status: $status"),
                Text("Payment: $paymentStatus"),
                Text("Price: ₺$price"),

                const SizedBox(height: 24),

                /// 💳 PAYMENT BUTTON
                if (paymentStatus != "paid")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/appointmentPayment',
                          arguments: appointmentId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E1B4F),
                      ),
                      child: const Text("Go to Payment"),
                    ),
                  ),

                /// ✅ COMPLETE BUTTON (vet side)
                if (status == "confirmed_paid")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('vet_appointments')
                            .doc(appointmentId)
                            .update({
                          "status": "completed",
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Marked as completed")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text("Mark as Completed"),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}