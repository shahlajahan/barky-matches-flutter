import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/ui/admin/admin_approval_page.dart';
import 'suspended_businesses_page.dart';
import '../../business/approved_businesses_page.dart';
import '../../business/rejected_businesses_page.dart';
import 'package:barky_matches_fixed/ui/admin/pages/admin_business_search_page.dart';
import 'admin_business_metrics_page.dart';
import '../dashboard/admin_dashboard_page.dart';
import 'admin_map_monitor_page.dart';
import 'admin_reports_page.dart';
import 'admin_fraud_analytics_page.dart';
import 'admin_complaint_center_page.dart';
import '../moderation/moderation_queue_page.dart';
import '../search/admin_search_page.dart';
import '../pages/audit_logs_page.dart';
import 'admin_metrics_page.dart';
import 'admin_revenue_page.dart';
import 'package:barky_matches_fixed/ui/admin/subscriptions/admin_subscription_page.dart';
import 'audit_logs_page.dart';
import '../user_satisfaction/admin_user_satisfaction_page.dart';

class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.pink,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
           _SectionTitle("BUSINESS"),
          _AdminItem(
            icon: Icons.verified_outlined,
            title: "Business Approvals",
            subtitle: "Pending & review requests",
            pageBuilder: () => const AdminApprovalPage(),
          ),

          // بقیه آیتم‌ها فعلاً Placeholder (بعداً وصل می‌کنیم)
          _AdminItem(
  icon: Icons.verified,
  title: "Approved Businesses",
  subtitle: "Manage active businesses",
  pageBuilder: () => const ApprovedBusinessesPage(),
),

_AdminItem(
  icon: Icons.cancel_outlined,
  title: "Rejected Businesses",
  subtitle: "Review rejected registrations",
  pageBuilder: () =>  RejectedBusinessesPage(),
),

          _AdminItem(
            icon: Icons.block_outlined,
            title: "Suspended Businesses",
            subtitle: "Manage suspended entities",
            pageBuilder: () => const SuspendedBusinessesPage(),
          ),
          _AdminItem(
  icon: Icons.credit_card_outlined,
  title: "Subscription Management",
  subtitle: "Plans & billing status",
  pageBuilder: () => const AdminSubscriptionPage(),
),

          const SizedBox(height: 18),
          const _SectionTitle("TRUST & SAFETY"),
          _AdminItem(
  icon: Icons.report_outlined,
  title: "Reports",
  subtitle: "Reported dogs, users, chats, businesses",
  pageBuilder: () => const AdminReportsPage(),
),

_AdminItem(
  icon: Icons.gavel_outlined,
  title: "Moderation Queue",
  subtitle: "Cases waiting for review",
  pageBuilder: () => const ModerationQueuePage(),
),

_AdminItem(
  icon: Icons.shield_outlined,
  title: "Fraud Analytics",
  subtitle: "Risk flags & fraud detection",
  pageBuilder: () => const AdminFraudAnalyticsPage(),
),
          _AdminItem(
  icon: Icons.warning_amber_outlined,
  title: "Complaint Center",
  subtitle: "User complaints & disputes",
  pageBuilder: () => const AdminComplaintCenterPage(),
),

          const SizedBox(height: 18),
          const _SectionTitle("ANALYTICS"),
                 _AdminItem(
  icon: Icons.dashboard_outlined,
  title: "Admin Dashboard",
  subtitle: "Platform overview",
  pageBuilder: () => const AdminDashboardPage(),
),
_AdminItem(
  icon: Icons.map,
  title: "Platform Map",
  subtitle: "Live system monitoring",
  pageBuilder: () => const AdminMapMonitorPage(),
),
                   _AdminItem(
  icon: Icons.bar_chart,
  title: "Platform Metrics",
  subtitle: "Platform KPI dashboard",
  pageBuilder: () => const AdminMetricsPage(),
),
          _AdminItem(
  icon: Icons.payments_outlined,
  title: "Revenue",
  subtitle: "Financial performance",
  pageBuilder: () => const AdminRevenuePage(),
),
          _AdminItem(
  icon: Icons.star_border,
  title: "User Satisfaction",
  subtitle: "Ratings & feedback overview",
  pageBuilder: () => const AdminUserSatisfactionPage(),
),
          _AdminItem(
  icon: Icons.analytics,
  title: "Business Metrics",
  subtitle: "Platform business statistics",
  pageBuilder: () => const AdminBusinessMetricsPage(),
),

          const SizedBox(height: 18),
          const _SectionTitle("SYSTEM"),
          _AdminItem(
  icon: Icons.search,
  title: "Global Business Search",
  subtitle: "Search all businesses",
  pageBuilder: () => const AdminBusinessSearchPage(),
),
          _AdminItem(
  icon: Icons.history,
  title: "Audit Logs",
  subtitle: "Admin action history",
  pageBuilder: () => const AuditLogsPage(),
),
          _AdminItem(
            icon: Icons.search,
            title: "Global Admin Search",
            subtitle: "Search businesses, users, reports",
            pageBuilder: () => const AdminSearchPage(),
          ),
        ],
      ),
    );
  }
}

class _AdminItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() pageBuilder;

  const _AdminItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => pageBuilder()),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.pink,
      ),
      body: const Center(child: Text("Coming soon...")),
    );
  }
}