import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/admin_kpi_card.dart';
import 'widgets/admin_activity_feed.dart';
import 'package:barky_matches_fixed/telegram_lab_page.dart';
import 'package:barky_matches_fixed/telegram_users_page.dart';

import 'package:barky_matches_fixed/ui/admin/diagnostics/pages/diagnostics_reports_page.dart'
    as diagnostics_ui;
import 'package:barky_matches_fixed/ui/admin/diagnostics/controllers/diagnostics_reports_controller.dart';
import 'package:barky_matches_fixed/ui/admin/diagnostics/repositories/diagnostics_reports_repository.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("📊 AdminDashboardPage BUILD");

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.adminDashboard),
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
                AppLocalizations.of(
                  context,
                )!.dashboardError('${businessSnap.error}'),
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
                Text(
                  AppLocalizations.of(context)!.platformOverview,
                  style: const TextStyle(
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

                Text(
                  AppLocalizations.of(context)!.adminActivity,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                /// -------------------------------
                /// ACTIVITY FEED
                /// -------------------------------
                const AdminActivityFeed(),

                const SizedBox(height: 30),

                Text(
                  AppLocalizations.of(context)!.developerTools,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.telegram, color: Colors.blue),
                    title: Text(AppLocalizations.of(context)!.telegramLab),
                    subtitle: Text(
                      AppLocalizations.of(context)!.testTelegramBotApi,
                    ),
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
                    leading: const Icon(Icons.bug_report, color: Colors.red),
                    title: Text(AppLocalizations.of(context)!.diagnostics),
                    subtitle: Text(
                      AppLocalizations.of(context)!.diagnosticsDescription,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => diagnostics_ui.DiagnosticsReportsPage(
                            controller: DiagnosticsReportsController(
                              repository:
                                  FirestoreDiagnosticsReportsRepository(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people, color: Colors.green),
                    title: Text(AppLocalizations.of(context)!.telegramUsers),
                    subtitle: Text(
                      AppLocalizations.of(context)!.telegramUsersDescription,
                    ),
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
