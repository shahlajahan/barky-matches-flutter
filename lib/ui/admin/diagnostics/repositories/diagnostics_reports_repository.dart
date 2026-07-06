import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/diagnostics_report_detail.dart';
import '../models/diagnostics_report_list_item.dart';
import '../models/diagnostics_report_log_entry.dart';
import '../models/diagnostics_reports_cursor.dart';
import '../models/diagnostics_reports_page.dart';
import '../models/diagnostics_reports_query.dart';

export '../models/diagnostics_report_detail.dart';
export '../models/diagnostics_report_list_item.dart';
export '../models/diagnostics_report_log_entry.dart';
export '../models/diagnostics_reports_cursor.dart';
export '../models/diagnostics_reports_date_range.dart';
export '../models/diagnostics_reports_page.dart';
export '../models/diagnostics_reports_query.dart';

abstract class DiagnosticsReportsRepository {
  Future<DiagnosticsReportsPage> fetchReports(DiagnosticsReportsQuery query);

  Future<DiagnosticsReportDetail?> getReportDetail(String reportId);
}

class FirestoreDiagnosticsReportsRepository
    implements DiagnosticsReportsRepository {
  FirestoreDiagnosticsReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionPath = 'diagnostic_reports';

  final FirebaseFirestore _firestore;

  @override
  Future<DiagnosticsReportsPage> fetchReports(
    DiagnosticsReportsQuery query,
  ) async {
    final int pageSize = query.pageSize < 1 ? 50 : query.pageSize;
    Query<Map<String, dynamic>> firestoreQuery = _reportsCollection;

    if (query.severity != null) {
      firestoreQuery = firestoreQuery.where(
        'clientReport.severity',
        isEqualTo: query.severity,
      );
    }

    if (query.reason != null) {
      firestoreQuery = firestoreQuery.where(
        'clientReport.reason',
        isEqualTo: query.reason,
      );
    }

    if (query.feature != null) {
      firestoreQuery = firestoreQuery.where(
        'clientReport.screen.feature',
        isEqualTo: query.feature,
      );
    }

    if (query.platform != null) {
      firestoreQuery = firestoreQuery.where(
        'clientReport.device.platform',
        isEqualTo: query.platform,
      );
    }

    if (query.version != null) {
      firestoreQuery = firestoreQuery.where(
        'clientReport.app.version',
        isEqualTo: query.version,
      );
    }

    final dateRange = query.dateRange;
    if (dateRange?.start != null) {
      firestoreQuery = firestoreQuery.where(
        'receivedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange!.start!),
      );
    }

    if (dateRange?.end != null) {
      firestoreQuery = firestoreQuery.where(
        'receivedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(dateRange!.end!),
      );
    }

    firestoreQuery = firestoreQuery.orderBy(
      'receivedAt',
      descending: query.sort == DiagnosticsReportsSort.newestFirst,
    );
    firestoreQuery = firestoreQuery.orderBy(
      FieldPath.documentId,
      descending: query.sort == DiagnosticsReportsSort.newestFirst,
    );

    final cursor = query.cursor;
    if (cursor != null) {
      if (cursor.sort != query.sort.name) {
        throw StateError(
          'Diagnostics reports cursor sort does not match query sort.',
        );
      }

      firestoreQuery = firestoreQuery.startAfter(<Object?>[
        Timestamp.fromDate(cursor.receivedAt),
        cursor.reportId,
      ]);
    }

    final snapshot = await firestoreQuery.limit(pageSize + 1).get();
    final documents = snapshot.docs;
    final pageDocuments = documents.take(pageSize).toList(growable: false);
    final hasMore = documents.length > pageSize;
    DiagnosticsReportsCursor? nextCursor;

    if (hasMore && pageDocuments.isNotEmpty) {
      nextCursor = _cursorFromDocument(pageDocuments.last, query.sort);
    }

    return DiagnosticsReportsPage(
      items: pageDocuments.map(_listItemFromDocument).toList(growable: false),
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<DiagnosticsReportDetail?> getReportDetail(String reportId) async {
    final document = await _reportsCollection.doc(reportId).get();

    if (!document.exists) {
      return null;
    }

    return _detailFromDocument(document);
  }

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection(_collectionPath);

  DiagnosticsReportsCursor _cursorFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
    DiagnosticsReportsSort sort,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return DiagnosticsReportsCursor(
      receivedAt:
          _dateValue(data['receivedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reportId: document.id,
      sort: sort.name,
    );
  }

  DiagnosticsReportListItem _listItemFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final clientReport = _mapValue(data['clientReport']);
    final app = _mapValue(clientReport['app']);
    final device = _mapValue(clientReport['device']);
    final screen = _mapValue(clientReport['screen']);
    final user = _mapValue(clientReport['user']);
    final logs = _listValue(clientReport['logs']);

    return DiagnosticsReportListItem(
      reportId: _stringValue(data['reportId']) ?? document.id,
      clientReportId: _stringValue(clientReport['clientReportId']),
      severity: _stringValue(clientReport['severity']) ?? '',
      reason: _stringValue(clientReport['reason']) ?? '',
      platform: _stringValue(device['platform']),
      version: _stringValue(app['version']),
      buildNumber: _stringValue(app['buildNumber']),
      feature: _stringValue(screen['feature']),
      screenName: _stringValue(screen['screenName']),
      route: _stringValue(screen['route']),
      uid: _stringValue(user['uid']),
      isGuest: _boolValue(user['isGuest']),
      receivedAt:
          _dateValue(data['receivedAt']) ??
          _dateValue(clientReport['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: _dateValue(clientReport['createdAt']),
      logCount: logs.length,
    );
  }

  DiagnosticsReportDetail _detailFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final clientReport = _mapValue(data['clientReport']);
    final app = _mapValue(clientReport['app']);
    final device = _mapValue(clientReport['device']);
    final screen = _mapValue(clientReport['screen']);
    final user = _mapValue(clientReport['user']);

    return DiagnosticsReportDetail(
      reportId: _stringValue(data['reportId']) ?? document.id,
      clientReportId: _stringValue(clientReport['clientReportId']),
      sessionId: _stringValue(clientReport['sessionId']),
      severity: _stringValue(clientReport['severity']) ?? '',
      reason: _stringValue(clientReport['reason']) ?? '',
      platform: _stringValue(device['platform']),
      version: _stringValue(app['version']),
      buildNumber: _stringValue(app['buildNumber']),
      buildMode: _stringValue(app['buildMode']),
      packageName: _stringValue(app['packageName']),
      manufacturer: _stringValue(device['manufacturer']),
      model: _stringValue(device['model']),
      osVersion: _stringValue(device['osVersion']),
      locale: _stringValue(device['locale']),
      timezone: _stringValue(device['timezone']),
      uid: _stringValue(user['uid']),
      isGuest: _boolValue(user['isGuest']),
      language: _stringValue(user['language']),
      role: _stringValue(user['role']),
      feature: _stringValue(screen['feature']),
      screenName: _stringValue(screen['screenName']),
      route: _stringValue(screen['route']),
      receivedAt:
          _dateValue(data['receivedAt']) ??
          _dateValue(clientReport['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: _dateValue(clientReport['createdAt']),
      logs: _listValue(
        clientReport['logs'],
      ).map(_logEntryFromValue).toList(growable: false),
    );
  }

  DiagnosticsReportLogEntry _logEntryFromValue(Object? value) {
    final log = _mapValue(value);

    return DiagnosticsReportLogEntry(
      timestamp:
          _dateValue(log['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      level: _stringValue(log['level']) ?? '',
      category: _stringValue(log['category']) ?? '',
      message: _stringValue(log['message']) ?? '',
      data: _nullableMapValue(log['data']),
      stackTrace: _stringValue(log['stackTrace']),
    );
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic>? _nullableMapValue(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<Object?> _listValue(Object? value) {
    if (value is List) {
      return value;
    }

    return const <Object?>[];
  }

  String? _stringValue(Object? value) => value?.toString();

  bool? _boolValue(Object? value) => value is bool ? value : null;

  DateTime? _dateValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
