import 'package:flutter/material.dart';

import '../controllers/diagnostics_report_details_controller.dart';
import '../controllers/diagnostics_reports_controller.dart';
import '../diagnostics_filter_options.dart';
import '../models/diagnostics_reports_date_range.dart';
import '../models/diagnostics_reports_query.dart';
import 'diagnostics_report_details_page.dart';
import '../widgets/diagnostics_reports_list.dart';
import '../widgets/diagnostics_statistics_section.dart';

class DiagnosticsReportsPage extends StatefulWidget {
  const DiagnosticsReportsPage({super.key, required this.controller});

  final DiagnosticsReportsController controller;

  @override
  State<DiagnosticsReportsPage> createState() => _DiagnosticsReportsPageState();
}

class _DiagnosticsReportsPageState extends State<DiagnosticsReportsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Reports'),
        actions: [
          TextButton(onPressed: _openFilters, child: const Text('Filters')),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          if (widget.controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.hasError) {
            return _DiagnosticsReportsErrorState(controller: widget.controller);
          }

          return Column(
            children: [
              DiagnosticsStatisticsSection(
                statistics: widget.controller.statistics,
                loading: widget.controller.statisticsLoading,
                error: widget.controller.statisticsError,
              ),
              Expanded(
                child: widget.controller.reports.isEmpty
                    ? const Center(child: Text('No diagnostic reports'))
                    : DiagnosticsReportsList(
                        scrollController: _scrollController,
                        reports: widget.controller.reports,
                        loadingMore: widget.controller.loadingMore,
                        onReportTap: _openReportDetails,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openReportDetails(String reportId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DiagnosticsReportDetailsPage(
          controller: DiagnosticsReportDetailsController(
            repository: widget.controller.repository,
            reportId: reportId,
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _DiagnosticsReportsFiltersSheet(
        query: widget.controller.query,
        onApply: widget.controller.applyQuery,
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 240) {
      widget.controller.loadMore();
    }
  }
}

class _DiagnosticsReportsFiltersSheet extends StatefulWidget {
  const _DiagnosticsReportsFiltersSheet({
    required this.query,
    required this.onApply,
  });

  final DiagnosticsReportsQuery query;
  final ValueChanged<DiagnosticsReportsQuery> onApply;

  @override
  State<_DiagnosticsReportsFiltersSheet> createState() =>
      _DiagnosticsReportsFiltersSheetState();
}

class _DiagnosticsReportsFiltersSheetState
    extends State<_DiagnosticsReportsFiltersSheet> {
  late String? _severity = widget.query.severity;
  late String? _reason = widget.query.reason;
  late String? _platform = widget.query.platform;
  late DiagnosticsReportsDateRange? _dateRange = widget.query.dateRange;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _DiagnosticsFilterDropdown(
              label: 'Severity',
              value: _severity,
              options: diagnosticsSeverityFilterOptions,
              onChanged: (value) => setState(() => _severity = value),
            ),
            const SizedBox(height: 12),
            _DiagnosticsFilterDropdown(
              label: 'Reason',
              value: _reason,
              options: diagnosticsReasonFilterOptions,
              onChanged: (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 12),
            _DiagnosticsFilterDropdown(
              label: 'Platform',
              value: _platform,
              options: diagnosticsPlatformFilterOptions,
              onChanged: (value) => setState(() => _platform = value),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _selectDateRange,
              child: Text(_dateRangeLabel),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _dateRangeLabel {
    final dateRange = _dateRange;
    if (dateRange?.start == null && dateRange?.end == null) {
      return 'Date Range';
    }

    return '${dateRange?.start?.toLocal().toString().split(' ').first ?? '-'}'
        ' - '
        '${dateRange?.end?.toLocal().toString().split(' ').first ?? '-'}';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day + 1),
      initialDateRange: _dateRange?.start != null && _dateRange?.end != null
          ? DateTimeRange(start: _dateRange!.start!, end: _dateRange!.end!)
          : null,
    );

    if (selectedRange == null) {
      return;
    }

    setState(() {
      _dateRange = DiagnosticsReportsDateRange(
        start: selectedRange.start,
        end: selectedRange.end,
      );
    });
  }

  void _apply() {
    widget.onApply(
      widget.query.copyWith(
        cursor: null,
        severity: _severity,
        reason: _reason,
        platform: _platform,
        dateRange: _dateRange,
      ),
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.onApply(
      widget.query.copyWith(
        cursor: null,
        severity: null,
        reason: null,
        platform: null,
        dateRange: null,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _DiagnosticsFilterDropdown extends StatelessWidget {
  const _DiagnosticsFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        for (final option in options)
          DropdownMenuItem<String?>(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}

class _DiagnosticsReportsErrorState extends StatelessWidget {
  const _DiagnosticsReportsErrorState({required this.controller});

  final DiagnosticsReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.error?.toString() ?? 'Unable to load reports',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
