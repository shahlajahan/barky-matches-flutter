import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../models/diagnostics_report_list_item.dart';

class DiagnosticsReportsList extends StatelessWidget {
  const DiagnosticsReportsList({
    super.key,
    required this.scrollController,
    required this.reports,
    required this.loadingMore,
    required this.onReportTap,
  });

  final ScrollController scrollController;
  final List<DiagnosticsReportListItem> reports;
  final bool loadingMore;
  final ValueChanged<String> onReportTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reports.length + (loadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == reports.length) {
          return const _DiagnosticsReportsLoadingFooter();
        }

        return _DiagnosticsReportListTile(
          report: reports[index],
          onTap: () => onReportTap(reports[index].reportId),
        );
      },
    );
  }
}

class _DiagnosticsReportsLoadingFooter extends StatelessWidget {
  const _DiagnosticsReportsLoadingFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
          Text(AppLocalizations.of(context)!.reasonValue(report.reason)),
          Text(
            AppLocalizations.of(context)!.featureValue(report.feature ?? '-'),
          ),
          Text(
            AppLocalizations.of(context)!.platformValue(
              report.platform ?? '-',
            ),
          ),
          Text(
            AppLocalizations.of(context)!.versionValue(report.version ?? '-'),
          ),
          Text(
            AppLocalizations.of(
              context,
            )!.receivedValue(report.receivedAt.toLocal().toString()),
          ),
        ],
      ),
    );
  }
}
