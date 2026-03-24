import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBusinessMetricsPage extends StatelessWidget {
  const AdminBusinessMetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Metrics"),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("businesses")
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          int total = docs.length;
          int approved = 0;
          int rejected = 0;
          int suspended = 0;
          int verified = 0;
          int risk = 0;

          for (var doc in docs) {

            final data = doc.data() as Map<String, dynamic>;

            final status = data["status"];

            if (status == "approved") approved++;
            if (status == "rejected") rejected++;
            if (status == "suspended") suspended++;

            final verification =
                (data["verification"] as Map?)?.cast<String, dynamic>() ?? {};

            if (verification["isVerified"] == true) verified++;

            final trust =
                (data["trust"] as Map?)?.cast<String, dynamic>() ?? {};

            final flags = (trust["riskFlags"] as List?) ?? [];

            if (flags.isNotEmpty) risk++;
          }

          double verificationRate =
              total == 0 ? 0 : (verified / total) * 100;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [

                _metricCard("Total Businesses", total, Colors.blue),

                _metricCard("Approved", approved, Colors.green),

                _metricCard("Rejected", rejected, Colors.red),

                _metricCard("Suspended", suspended, Colors.orange),

                _metricCard(
                  "Verification Rate",
                  "${verificationRate.toStringAsFixed(1)}%",
                  Colors.purple,
                ),

                _metricCard("Risk Flags", risk, Colors.deepOrange),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String title, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}