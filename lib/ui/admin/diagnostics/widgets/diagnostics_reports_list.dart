import 'package:flutter/material.dart';

import '../models/diagnostics_report_list_item.dart';

class DiagnosticsReportsList extends StatelessWidget {
  const DiagnosticsReportsList({
    super.key,
    required this.reports,
    required this.onReportTap,
  });

  final List<DiagnosticsReportListItem> reports;
  final ValueChanged<String> onReportTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reports.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _DiagnosticsReportListTile(
          report: reports[index],
          onTap: () => onReportTap(reports[index].reportId),
        );
      },
    );
  }
}

class _DiagnosticsReportListTile extends StatelessWidget {
  const _DiagnosticsReportListTile({required this.report, required this.onTap});

  final DiagnosticsReportListItem report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
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
