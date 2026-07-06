import 'package:flutter/material.dart';

import '../controllers/diagnostics_report_details_controller.dart';
import '../controllers/diagnostics_reports_controller.dart';
import 'diagnostics_report_details_page.dart';
import '../widgets/diagnostics_reports_list.dart';

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
      appBar: AppBar(title: const Text('Diagnostic Reports')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          if (widget.controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.hasError) {
            return _DiagnosticsReportsErrorState(controller: widget.controller);
          }

          if (widget.controller.reports.isEmpty) {
            return const Center(child: Text('No diagnostic reports'));
          }

          return DiagnosticsReportsList(
            scrollController: _scrollController,
            reports: widget.controller.reports,
            loadingMore: widget.controller.loadingMore,
            onReportTap: _openReportDetails,
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
