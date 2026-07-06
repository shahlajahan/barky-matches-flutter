import 'package:flutter/foundation.dart';

import '../repositories/diagnostics_reports_repository.dart';

class DiagnosticsReportsController extends ChangeNotifier {
  DiagnosticsReportsController({
    required this.repository,
    DiagnosticsReportsQuery initialQuery = const DiagnosticsReportsQuery(),
  }) : _query = initialQuery;

  final DiagnosticsReportsRepository repository;

  final DiagnosticsReportsQuery _query;
  // ignore: prefer_final_fields
  bool _loading = false;
  // ignore: prefer_final_fields
  List<DiagnosticsReportListItem> _reports =
      const <DiagnosticsReportListItem>[];
  Object? _error;
  DiagnosticsReportsCursor? _cursor;
  // ignore: prefer_final_fields
  bool _hasMore = false;

  DiagnosticsReportsQuery get query => _query;
  bool get loading => _loading;
  List<DiagnosticsReportListItem> get reports =>
      List<DiagnosticsReportListItem>.unmodifiable(_reports);
  Object? get error => _error;
  DiagnosticsReportsCursor? get cursor => _cursor;
  bool get hasMore => _hasMore;
  bool get hasError => _error != null;

  Future<void> loadInitial() async {}

  Future<void> refresh() async {}

  Future<void> loadMore() async {}

  Future<void> retry() async {}

  Future<void> applyQuery(DiagnosticsReportsQuery query) async {}
}
