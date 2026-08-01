import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../controllers/diagnostics_report_details_controller.dart';
import '../models/diagnostics_report_detail.dart';
import '../models/diagnostics_report_log_entry.dart';

class DiagnosticsReportDetailsPage extends StatefulWidget {
  const DiagnosticsReportDetailsPage({super.key, required this.controller});

  final DiagnosticsReportDetailsController controller;

  @override
  State<DiagnosticsReportDetailsPage> createState() =>
      _DiagnosticsReportDetailsPageState();
}

class _DiagnosticsReportDetailsPageState
    extends State<DiagnosticsReportDetailsPage> {
  @override
  void initState() {
    super.initState();

    widget.controller.loadReportDetail();
  }

  @override
  void dispose() {
    widget.controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.diagnosticReport),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          if (widget.controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.controller.error?.toString() ??
                      'Unable to load report',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final report = widget.controller.detail;
          if (report == null) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.diagnosticReportNotFound,
              ),
            );
          }

          return _DiagnosticsReportDetailsView(
            controller: widget.controller,
            report: report,
          );
        },
      ),
    );
  }
}

class _DiagnosticsReportDetailsView extends StatelessWidget {
  const _DiagnosticsReportDetailsView({
    required this.controller,
    required this.report,
  });

  final DiagnosticsReportDetailsController controller;
  final DiagnosticsReportDetail report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailsSection(
          title: 'Summary',
          rows: [
            _DetailsRow('Severity', report.severity),
            _DetailsRow('Reason', report.reason),
            _DetailsRow('Status', report.status),
            _DetailsRow('Message', report.message),
            _DetailsRow('Feature', report.feature),
            _DetailsRow('Screen', report.screenName),
            _DetailsRow('Route', report.route),
            _DetailsRow('Widget', report.widgetName),
            _DetailsRow('Platform', report.platform),
            _DetailsRow('Version', report.version),
            _DetailsRow('Build Number', report.buildNumber),
            _DetailsRow('Received At', report.receivedAt.toLocal().toString()),
          ],
        ),
        _ActionsSection(controller: controller, report: report),
        _DetailsSection(
          title: 'Client',
          rows: [
            _DetailsRow('User Id', report.uid),
            _DetailsRow('Session Id', report.sessionId),
            _DetailsRow('App Version', report.version),
            _DetailsRow('Build Number', report.buildNumber),
            _DetailsRow('Resolved At', report.resolvedAt?.toLocal().toString()),
            _DetailsRow('Ignored At', report.ignoredAt?.toLocal().toString()),
            _DetailsRow('Admin UID', report.adminUid),
          ],
        ),
        _DetailsSection(
          title: 'Device',
          rows: [
            _DetailsRow('OS', report.osVersion),
            _DetailsRow('Device Model', report.model),
            _DetailsRow('Platform', report.platform),
            _DetailsRow('Locale', report.locale),
          ],
        ),
        _StackTraceSection(stackTrace: report.stackTrace),
        _LogsSection(logs: report.logs),
        _RawJsonSection(rawJson: report.rawJson),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.controller, required this.report});

  final DiagnosticsReportDetailsController controller;
  final DiagnosticsReportDetail report;

  @override
  Widget build(BuildContext context) {
    final status = report.status.toLowerCase();
    final actionInProgress = controller.actionInProgress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.actionsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (status == 'resolved' || status == 'ignored')
              ElevatedButton(
                onPressed: actionInProgress ? null : controller.reopen,
                child: Text(AppLocalizations.of(context)!.reopen),
              )
            else ...[
              ElevatedButton(
                onPressed: actionInProgress ? null : controller.markResolved,
                child: Text(AppLocalizations.of(context)!.resolve),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: actionInProgress ? null : controller.ignore,
                child: Text(AppLocalizations.of(context)!.ignore),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StackTraceSection extends StatelessWidget {
  const _StackTraceSection({required this.stackTrace});

  final String? stackTrace;

  @override
  Widget build(BuildContext context) {
    final value = stackTrace?.trim();
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.stackTrace,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(value),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.rows});

  final String title;
  final List<_DetailsRow> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows
        .where((row) => row.value != null && row.value!.isNotEmpty)
        .toList(growable: false);

    if (visibleRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final row in visibleRows) _DetailTextRow(row: row),
          ],
        ),
      ),
    );
  }
}

class _DetailsRow {
  const _DetailsRow(this.label, this.value);

  final String label;
  final String? value;
}

class _DetailTextRow extends StatelessWidget {
  const _DetailTextRow({required this.row});

  final _DetailsRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(row.value ?? '-'),
        ],
      ),
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.logs});

  final List<DiagnosticsReportLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.breadcrumbsLogs,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              Text(AppLocalizations.of(context)!.noLogs)
            else
              for (final log in logs) _LogEntryRow(log: log),
          ],
        ),
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.log});

  final DiagnosticsReportLogEntry log;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log.timestamp.toLocal().toString()),
          Text('${log.level} / ${log.category}'),
          Text(log.message),
          if (log.stackTrace?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            SelectableText(log.stackTrace!),
          ],
        ],
      ),
    );
  }
}

class _RawJsonSection extends StatelessWidget {
  const _RawJsonSection({required this.rawJson});

  final Map<String, dynamic> rawJson;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(AppLocalizations.of(context)!.rawJson),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText(const JsonEncoder.withIndent('  ').convert(rawJson)),
        ],
      ),
    );
  }
}
