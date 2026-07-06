import 'package:flutter/material.dart';

import '../models/diagnostics_report_list_item.dart';

class DiagnosticsReportsList extends StatelessWidget {
  const DiagnosticsReportsList({super.key, required this.reports});

  final List<DiagnosticsReportListItem> reports;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reports.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _DiagnosticsReportListTile(report: reports[index]);
      },
    );
  }
}

class _DiagnosticsReportListTile extends StatelessWidget {
  const _DiagnosticsReportListTile({required this.report});

  final DiagnosticsReportListItem report;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(report.severity),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reason: ${report.reason}'),
          Text('Feature: ${report.feature ?? '-'}'),
          Text('Platform: ${report.platform ?? '-'}'),
          Text('Version: ${report.version ?? '-'}'),
          Text('Received: ${report.receivedAt.toLocal()}'),
        ],
      ),
    );
  }
}
