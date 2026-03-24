import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRevenuePage extends StatelessWidget {
  const AdminRevenuePage({super.key});

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("admin_stats")
        .doc("revenue")
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Revenue"),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: stream,
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
              child: Text("No revenue data"),
            );
          }

          final premiumUsers = (data["premiumUsers"] as num?)?.toInt() ?? 0;
          final totalRevenue = (data["totalRevenue"] ?? 0).toDouble();

          final arpu = premiumUsers == 0
              ? 0
              : (totalRevenue / premiumUsers).toStringAsFixed(2);

          return Padding(
            padding: const EdgeInsets.all(16),

            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.4,

              children: [

                _RevenueCard(
                  title: "Premium Users",
                  value: premiumUsers,
                  icon: Icons.star,
                ),

                _RevenueCard(
                  title: "Business Subs",
                  value: data["businessSubscriptions"] ?? 0,
                  icon: Icons.store,
                ),

                _RevenueCard(
                  title: "Monthly Revenue",
                  value: "\$${data["monthlyRevenue"] ?? 0}",
                  icon: Icons.trending_up,
                ),

                _RevenueCard(
                  title: "Total Revenue",
                  value: "\$${data["totalRevenue"] ?? 0}",
                  icon: Icons.payments,
                ),

                _RevenueCard(
                  title: "New Subs Today",
                  value: data["newSubscriptionsToday"] ?? 0,
                  icon: Icons.person_add,
                ),

                _RevenueCard(
                  title: "Active Subs",
                  value: data["activeSubscriptions"] ?? 0,
                  icon: Icons.verified,
                ),

                _RevenueCard(
                  title: "Expiring Soon",
                  value: data["expiringSoon"] ?? 0,
                  icon: Icons.warning,
                ),

                _RevenueCard(
                  title: "ARPU",
                  value: "\$$arpu",
                  icon: Icons.analytics,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {

  final String title;
  final dynamic value;
  final IconData icon;

  const _RevenueCard({
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
            color: Colors.green,
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