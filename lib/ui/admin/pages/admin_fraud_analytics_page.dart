import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';

class AdminFraudAnalyticsPage extends StatelessWidget {
  const AdminFraudAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {

    final moderationStream = FirebaseFirestore.instance
        .collection("admin_stats")
        .doc("moderation")
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fraud Analytics"),
        backgroundColor: AppTheme.primary,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: moderationStream,
        builder: (context, snapshot) {

          // loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading analytics",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data?.data() ?? {};

          final reportsToday = data["reportsToday"] ?? 0;
          final autoHidden = data["autoHiddenContent"] ?? 0;
          final reportsRejected = data["reportsRejected"] ?? 0;
          final reportsApproved = data["reportsApproved"] ?? 0;
          final suspiciousClusters = data["suspiciousReportClusters"] ?? 0;
final massAttacks = data["massReportingAttacks"] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              const _SectionTitle("MODERATION METRICS"),

              _StatCard(
                icon: Icons.report_outlined,
                title: "Reports Today",
                value: reportsToday.toString(),
              ),

              _StatCard(
                icon: Icons.visibility_off_outlined,
                title: "Auto Hidden Content",
                value: autoHidden.toString(),
              ),

              _StatCard(
                icon: Icons.check_circle_outline,
                title: "Reports Approved",
                value: reportsApproved.toString(),
              ),

              _StatCard(
                icon: Icons.cancel_outlined,
                title: "Reports Rejected",
                value: reportsRejected.toString(),
              ),

              _StatCard(
  icon: Icons.warning_amber,
  title: "Suspicious Report Clusters",
  value: suspiciousClusters.toString(),
),

_StatCard(
  icon: Icons.security,
  title: "Mass Reporting Attacks",
  value: massAttacks.toString(),
),

              const SizedBox(height: 24),

              const _SectionTitle("RISK INDICATORS"),

              const _RiskCard(
                icon: Icons.warning_amber_outlined,
                title: "Mass Reporting Detection",
                description:
                    "Detect coordinated reporting attacks against a target.",
              ),

              const _RiskCard(
                icon: Icons.person_off_outlined,
                title: "Abusive Reporter Detection",
                description:
                    "Users submitting too many false reports.",
              ),

              const _RiskCard(
                icon: Icons.group_outlined,
                title: "Suspicious User Clusters",
                description:
                    "Multiple accounts reporting the same entity.",
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {

  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {

  final IconData icon;
  final String title;
  final String description;

  const _RiskCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}