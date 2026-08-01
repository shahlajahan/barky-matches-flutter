import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import '../../core/debug/diagnostics_queue.dart';
import '../../core/debug/diagnostics_report.dart';
import '../../core/debug/diagnostics_uploader.dart';
import '../../core/debug/firestore_permission_diagnostics.dart';
import '../widgets/tool_card.dart';

class DiagnosticsSection extends StatefulWidget {
  const DiagnosticsSection({super.key});

  @override
  State<DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends State<DiagnosticsSection> {
  final DiagnosticsQueue _queue = DiagnosticsQueue();
  final DiagnosticsUploader _uploader = DiagnosticsUploader();

  bool _loading = true;
  bool _busy = false;
  int _queueSize = 0;
  DiagnosticsReport? _lastReport;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final List<DiagnosticsReport> reports = await _queue.pendingReports();
    if (!mounted) {
      return;
    }

    setState(() {
      _queueSize = reports.length;
      _lastReport = reports.isEmpty ? null : reports.last;
      _loading = false;
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await action();
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });
    }
  }

  void _throwTestException() {
    Future<void>.microtask(() {
      throw StateError('Developer Tools test exception');
    });
  }

  Future<void> _testFirestorePermissionDenied() async {
    try {
      await FirebaseFirestore.instance
          .collection('permission_denied_test')
          .doc('probe')
          .set({
        'type': 'developer_tools_permission_test',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await FirestorePermissionDiagnostics.reportIfNeeded(
          e,
          failurePath: 'DeveloperTools.testPermissionDenied',
          message: 'Developer Tools test Firestore permission denied',
          data: <String, dynamic>{
            'collection': 'permission_denied_test',
            'documentId': 'probe',
          },
        );
      }
    }
  }

  String _lastReportDetails() {
    final DiagnosticsReport? report = _lastReport;
    if (report == null) {
      return 'No reports queued.';
    }

    final DateTime localCreatedAt = report.createdAt.toLocal();
    final String month = localCreatedAt.month.toString().padLeft(2, '0');
    final String day = localCreatedAt.day.toString().padLeft(2, '0');
    final String hour = localCreatedAt.hour.toString().padLeft(2, '0');
    final String minute = localCreatedAt.minute.toString().padLeft(2, '0');

    return '${report.reason}\n'
        'Created: ${localCreatedAt.year}-$month-$day $hour:$minute\n'
        'Session: ${report.sessionId}\n'
        'Logs: ${report.logCount}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.diagnosticsSectionTitle,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.diagnosticsSectionDescription,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: 'Throw Test Exception',
          description: 'Trigger an unhandled exception for diagnostics testing.',
          trailing: FilledButton(
            onPressed: _busy ? null : _throwTestException,
            child: Text(l10n.diagnosticsThrowButton),
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Test Firestore Permission Denied',
          description:
              'Attempt a write to an intentionally unruled Firestore path for diagnostics testing.',
          trailing: FilledButton(
            onPressed: _busy
                ? null
                : () {
                    unawaited(_runBusy(_testFirestorePermissionDenied));
                  },
            child: Text(l10n.diagnosticsTestButton),
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Upload Pending Reports',
          description: 'Attempt to upload queued reports using the diagnostics uploader.',
          trailing: FilledButton(
            onPressed: _busy
                ? null
                : () {
                    unawaited(
                      _runBusy(() async {
                        await _uploader.uploadPendingReports();
                        await _refresh();
                      }),
                    );
                  },
            child: Text(l10n.diagnosticsUploadButton),
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Queue Size',
          description: _loading ? 'Loading queue size...' : 'Pending reports: $_queueSize',
          trailing: OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    unawaited(_runBusy(_refresh));
                  },
            child: Text(l10n.diagnosticsRefreshButton),
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Last Report',
          description: _loading ? 'Loading latest report...' : _lastReportDetails(),
          trailing: OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    unawaited(_runBusy(_refresh));
                  },
            child: Text(l10n.diagnosticsRefreshButton),
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Clear Queue',
          description: 'Remove all pending diagnostics reports from local storage.',
          trailing: FilledButton.tonal(
            onPressed: _busy
                ? null
                : () {
                    unawaited(
                      _runBusy(() async {
                        await _queue.clear();
                        await _refresh();
                      }),
                    );
                  },
            child: Text(l10n.diagnosticsClearButton),
          ),
        ),
      ],
    );
  }
}
