import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/admin_kpi_card.dart';
import 'widgets/admin_activity_feed.dart';

class AdminDashboardPage extends StatelessWidget {

  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {

    print("📊 AdminDashboardPage BUILD");

    return Scaffold(

      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.pink,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("businesses")
            .snapshots(),

        builder: (context, businessSnap) {

          /// -------------------------------
          /// DEBUG SNAPSHOT STATE
          /// -------------------------------
          print("📡 Dashboard snapshot state:");
          print("  hasData: ${businessSnap.hasData}");
          print("  hasError: ${businessSnap.hasError}");
          print("  connectionState: ${businessSnap.connectionState}");

          /// -------------------------------
          /// ERROR HANDLING
          /// -------------------------------
          if (businessSnap.hasError) {

            print("❌ Firestore ERROR:");
            print(businessSnap.error);

            return Center(
              child: Text(
                "Dashboard Error:\n${businessSnap.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          /// -------------------------------
          /// LOADING STATE
          /// -------------------------------
          if (!businessSnap.hasData) {

            print("⏳ Waiting for businesses snapshot...");

            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final businesses = businessSnap.data!.docs;

          print("✅ Businesses loaded: ${businesses.length}");

          int approved = 0;
          int rejected = 0;
          int suspended = 0;
          int risk = 0;

          /// -------------------------------
          /// KPI CALCULATION
          /// -------------------------------
          for (var doc in businesses) {

            final data = doc.data() as Map<String,dynamic>;

            final status = data["status"];

            if (status == "approved") approved++;
            if (status == "rejected") rejected++;
            if (status == "suspended") suspended++;

            final trust =
                (data["trust"] as Map?)?.cast<String,dynamic>() ?? {};

            final flags = trust["riskFlags"] as List?;

            if (flags != null && flags.isNotEmpty) {
              risk++;
            }

          }

          print("📊 KPI Stats:");
          print("  approved: $approved");
          print("  rejected: $rejected");
          print("  suspended: $suspended");
          print("  risk flags: $risk");

          /// -------------------------------
          /// UI
          /// -------------------------------
          return SingleChildScrollView(

            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  "Platform Overview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [

                    AdminKpiCard(
                      title: "Businesses",
                      value: businesses.length.toString(),
                      color: Colors.blue,
                      icon: Icons.business,
                    ),

                    AdminKpiCard(
                      title: "Approved",
                      value: approved.toString(),
                      color: Colors.green,
                      icon: Icons.verified,
                    ),

                    AdminKpiCard(
                      title: "Rejected",
                      value: rejected.toString(),
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),

                    AdminKpiCard(
                      title: "Suspended",
                      value: suspended.toString(),
                      color: Colors.orange,
                      icon: Icons.block,
                    ),

                    AdminKpiCard(
                      title: "Risk Flags",
                      value: risk.toString(),
                      color: Colors.deepOrange,
                      icon: Icons.warning,
                    ),

                  ],
                ),

                const SizedBox(height: 30),

                const Text(
                  "Admin Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                /// -------------------------------
                /// ACTIVITY FEED
                /// -------------------------------
                const AdminActivityFeed(),

              ],
            ),
          );
        },
      ),
    );
  }
}