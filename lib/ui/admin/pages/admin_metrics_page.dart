import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMetricsPage extends StatelessWidget {
  const AdminMetricsPage({super.key});

  @override
  Widget build(BuildContext context) {

    final doc = FirebaseFirestore.instance
        .collection("admin_stats")
        .doc("metrics")
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Platform Metrics"),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: doc,
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(
              child: Text("No metrics data"),
            );
          }

          final updatedAt = data["updatedAt"] as Timestamp?;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.4,
                    children: [

                      _MetricCard(
                        title: "Total Users",
                        value: data["totalUsers"] ?? 0,
                        icon: Icons.people,
                      ),

                      _MetricCard(
                        title: "Active Users",
                        value: data["activeUsers24h"] ?? 0,
                        icon: Icons.person_outline,
                      ),

                      _MetricCard(
                        title: "Dogs Registered",
                        value: data["dogsRegistered"] ?? 0,
                        icon: Icons.pets,
                      ),

                      _MetricCard(
                        title: "Reports Today",
                        value: data["reportsToday"] ?? 0,
                        icon: Icons.flag,
                      ),

                      _MetricCard(
                        title: "Complaints Open",
                        value: data["complaintsOpen"] ?? 0,
                        icon: Icons.warning,
                      ),

                      _MetricCard(
                        title: "Approved Businesses",
                        value: data["businessesApproved"] ?? 0,
                        icon: Icons.store,
                      ),

                      _MetricCard(
                        title: "Open Reports",
                        value: data["reportsOpen"] ?? 0,
                        icon: Icons.report,
                      ),

                      _MetricCard(
                        title: "Playdates Today",
                        value: data["playDatesToday"] ?? 0,
                        icon: Icons.calendar_today,
                      ),

                    ],
                  ),
                ),

                if (updatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      "Last updated: ${updatedAt.toDate()}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
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

class _MetricCard extends StatelessWidget {

  final String title;
  final dynamic value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(.08),
          )
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Icon(
            icon,
            size: 28,
            color: Colors.pink,
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "$value",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}