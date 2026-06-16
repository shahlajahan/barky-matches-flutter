import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/admin_kpi_card.dart';
import 'widgets/admin_activity_feed.dart';
import 'package:barky_matches_fixed/telegram_lab_page.dart';
import 'package:barky_matches_fixed/telegram_users_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("📊 AdminDashboardPage BUILD");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.pink,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("businesses").snapshots(),

        builder: (context, businessSnap) {
          /// -------------------------------
          /// DEBUG SNAPSHOT STATE
          /// -------------------------------
          debugPrint("📡 Dashboard snapshot state:");
          debugPrint("  hasData: ${businessSnap.hasData}");
          debugPrint("  hasError: ${businessSnap.hasError}");
          debugPrint("  connectionState: ${businessSnap.connectionState}");

          /// -------------------------------
          /// ERROR HANDLING
          /// -------------------------------
          if (businessSnap.hasError) {
            debugPrint("❌ Firestore ERROR:");
            debugPrint(businessSnap.error.toString());

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
            debugPrint("⏳ Waiting for businesses snapshot...");

            return const Center(child: CircularProgressIndicator());
          }

          final businesses = businessSnap.data!.docs;

          debugPrint("✅ Businesses loaded: ${businesses.length}");

          int approved = 0;
          int rejected = 0;
          int suspended = 0;
          int risk = 0;

          /// -------------------------------
          /// KPI CALCULATION
          /// -------------------------------
          for (var doc in businesses) {
            final data = doc.data() as Map<String, dynamic>;

            final status = data["status"];

            if (status == "approved") approved++;
            if (status == "rejected") rejected++;
            if (status == "suspended") suspended++;

            final trust =
                (data["trust"] as Map?)?.cast<String, dynamic>() ?? {};

            final flags = trust["riskFlags"] as List?;

            if (flags != null && flags.isNotEmpty) {
              risk++;
            }
          }

          debugPrint("📊 KPI Stats:");
          debugPrint("  approved: $approved");
          debugPrint("  rejected: $rejected");
          debugPrint("  suspended: $suspended");
          debugPrint("  risk flags: $risk");

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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                /// -------------------------------
                /// ACTIVITY FEED
                /// -------------------------------
                const AdminActivityFeed(),

                const SizedBox(height: 30),

const Text(
  "Developer Tools",
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 10),

Card(
  child: ListTile(
    leading: const Icon(Icons.telegram, color: Colors.blue),
    title: const Text("Telegram Lab"),
    subtitle: const Text("Test Telegram Bot API"),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TelegramLabPage(),
        ),
      );
    },
  ),
),

Card(
  child: ListTile(
    leading: const Icon(
      Icons.people,
      color: Colors.green,
    ),
    title: const Text("Telegram Users"),
    subtitle: const Text("View connected Telegram users"),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TelegramUsersPage(),
        ),
      );
    },
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
