import 'package:flutter/foundation.dart';

import '../repositories/diagnostics_reports_repository.dart';

class DiagnosticsReportsController extends ChangeNotifier {
  DiagnosticsReportsController({
    required this.repository,
    DiagnosticsReportsQuery initialQuery = const DiagnosticsReportsQuery(),
  }) : _query = initialQuery;

  final DiagnosticsReportsRepository repository;

  DiagnosticsReportsQuery _query;
  // ignore: prefer_final_fields
  bool _loading = false;
  // ignore: prefer_final_fields
  List<DiagnosticsReportListItem> _reports =
      const <DiagnosticsReportListItem>[];
  Object? _error;
  DiagnosticsReportsCursor? _cursor;
  // ignore: prefer_final_fields
  bool _hasMore = false;
  // ignore: prefer_final_fields
  bool _loadingMore = false;

  DiagnosticsReportsQuery get query => _query;
  bool get loading => _loading;
  List<DiagnosticsReportListItem> get reports =>
      List<DiagnosticsReportListItem>.unmodifiable(_reports);
  Object? get error => _error;
  DiagnosticsReportsCursor? get cursor => _cursor;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  bool get hasError => _error != null;

  Future<void> loadInitial() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final DiagnosticsReportsPage page = await repository.fetchReports(_query);

      _reports = List<DiagnosticsReportListItem>.unmodifiable(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {}

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }

    final cursor = _cursor;
    if (cursor == null) {
      return;
    }

    _loadingMore = true;
    notifyListeners();

    try {
      final DiagnosticsReportsPage page = await repository.fetchReports(
        _queryWithCursor(cursor),
      );

      _reports = List<DiagnosticsReportListItem>.unmodifiable([
        ..._reports,
        ...page.items,
      ]);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {}

  Future<void> applyQuery(DiagnosticsReportsQuery query) async {
    _query = query;
    _reports = const <DiagnosticsReportListItem>[];
    _cursor = null;
    _hasMore = false;
    _loadingMore = false;

    await loadInitial();
  }

  DiagnosticsReportsQuery _queryWithCursor(DiagnosticsReportsCursor cursor) {
    return _query.copyWith(cursor: cursor);
  }
}
