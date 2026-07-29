import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/report_model.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/admin/moderation/widgets/report_moderation_card.dart';

/// The single production report-moderation screen. Replaces the old raw-ID
/// debug list and the duplicate InvestigationPage/ModerationQueuePage report
/// path - one screen, one card, one review flow for every report type.
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _statuses = ['pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'approved':
        return l10n.adminReportsTabApproved;
      case 'rejected':
        return l10n.adminReportsTabRejected;
      default:
        return l10n.adminReportsTabPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminReportsTitle),
        backgroundColor: AppTheme.primary,
        bottom: TabBar(
          controller: _tabController,
          tabs: _statuses
              .map((status) => Tab(text: _tabLabel(l10n, status)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) => _ReportsList(status: status)).toList(),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final String status;

  const _ReportsList({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(l10n.adminReportsLoadError('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(l10n.adminReportsEmpty(status)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final report = Report.fromFirestore(docs[index]);
            return ReportModerationCard(key: ValueKey(report.id), report: report);
          },
        );
      },
    );
  }
}
