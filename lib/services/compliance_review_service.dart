import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller, marketplaceFunctionsRegion;

/// Marketplace Revision 30 §J Slice 4 — the admin evidence review boundary.
///
/// Every operation here goes through an existing server callable. This class
/// performs NO direct write to `complianceDocuments`, `complianceReviewEvents`,
/// scopes, links, decisions, policies, products, inventory or businesses —
/// all of which remain `create, update, delete: if false` for every client,
/// admin included. Reads are the admin-only Rules reads that already exist.
///
/// Approval here means exactly one thing: this compliance DOCUMENT is
/// approved. It creates no scope, no evidence link, no product decision, no
/// classification, no eligibility, no activation and no publication — those
/// are Revision 30 §J slices 5-7 and nothing in this file anticipates them.

/// The frozen `COMPLIANCE_DOCUMENT_STATUS` vocabulary.
enum ComplianceDocumentStatus {
  clean('clean'),
  pendingReview('pending_review'),
  approved('approved'),
  rejected('rejected'),
  revoked('revoked'),
  expired('expired'),
  superseded('superseded');

  const ComplianceDocumentStatus(this.wireValue);
  final String wireValue;
}

/// Fail-closed parse. A value the client does not recognise — a future
/// status, a malformed one, an absent one — returns null and must never be
/// treated as actionable.
ComplianceDocumentStatus? complianceDocumentStatusFromWire(Object? value) {
  if (value is! String) return null;
  for (final s in ComplianceDocumentStatus.values) {
    if (s.wireValue == value) return s;
  }
  return null;
}

/// The only status in which a decision may be taken. A positive allowlist.
const Set<ComplianceDocumentStatus> complianceDecidableStatuses = {
  ComplianceDocumentStatus.pendingReview,
};

enum ComplianceReviewFailureKind {
  unauthenticated,
  notAdmin,
  notFound,

  /// The document is no longer `pending_review` — another admin decided it,
  /// or it moved on. The UI must refresh canonical state, never retry blindly.
  staleDecision,

  /// Already decided with different values.
  conflict,
  invalidInput,

  /// Evidence could not be retrieved or its authorization expired.
  evidenceUnavailable,
  unavailableRetry,
  generic,
}

class ComplianceReviewException implements Exception {
  final ComplianceReviewFailureKind kind;
  const ComplianceReviewException(this.kind);
  @override
  String toString() => 'ComplianceReviewException($kind)';
}

/// One queue row. Only review-safe fields: no storage path, no bucket, no
/// upload nonce, no scanner internals, no owner uid.
class ComplianceReviewItem {
  const ComplianceReviewItem({
    required this.documentId,
    required this.businessId,
    required this.documentType,
    required this.sellerRelationship,
    required this.status,
    required this.rawStatus,
    this.validUntil,
    this.uploadedAt,
    this.contentHash,
    this.sizeBytes,
  });

  final String documentId;
  final String businessId;
  final String? documentType;
  final String? sellerRelationship;

  /// Null when the server reported a status this client does not recognise.
  /// Such a row is diagnostic only and can never be acted on.
  final ComplianceDocumentStatus? status;
  final String? rawStatus;

  final DateTime? validUntil;
  final DateTime? uploadedAt;
  final String? contentHash;
  final int? sizeBytes;

  bool get isDecidable =>
      status != null && complianceDecidableStatuses.contains(status);

  static ComplianceReviewItem fromSnapshot(
    String documentId,
    Map<String, dynamic> data,
  ) {
    DateTime? asDate(Object? v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final raw = data['status'];
    return ComplianceReviewItem(
      documentId: documentId,
      businessId: data['businessId'] is String
          ? data['businessId'] as String
          : '',
      documentType: data['documentType'] is String
          ? data['documentType'] as String
          : null,
      sellerRelationship: data['sellerRelationship'] is String
          ? data['sellerRelationship'] as String
          : null,
      status: complianceDocumentStatusFromWire(raw),
      rawStatus: raw is String ? raw : null,
      validUntil: asDate(data['validUntil']),
      uploadedAt: asDate(data['uploadedAt']),
      contentHash: data['contentHash'] is String
          ? data['contentHash'] as String
          : null,
      sizeBytes: data['sizeBytes'] is int ? data['sizeBytes'] as int : null,
    );
  }
}

/// A short-lived authorization to view one evidence object.
///
/// [downloadUrl] is a bearer capability with a ~90 second life. It is held in
/// memory for the duration of one review screen and never persisted, logged,
/// routed, copied to the clipboard or written to analytics.
class ComplianceEvidenceGrant {
  const ComplianceEvidenceGrant({
    required this.documentId,
    required this.downloadUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.contentHash,
    required this.expiresAtMs,
  });

  final String documentId;
  final String downloadUrl;
  final String contentType;
  final int sizeBytes;
  final String contentHash;
  final int expiresAtMs;

  bool isExpiredAt(DateTime now) => now.millisecondsSinceEpoch >= expiresAtMs;

  /// Only the frozen intake types may be shown at all.
  bool get isSupported => const {
    'application/pdf',
    'image/jpeg',
    'image/png',
  }.contains(contentType);

  /// JPEG and PNG render inline safely. PDF does not: this app has no vetted
  /// in-app PDF component, and Slice 4's authorization forbids adding an
  /// arbitrary webview for it, so PDF uses the external-open fallback.
  bool get canRenderInline =>
      contentType == 'image/jpeg' || contentType == 'image/png';

  static ComplianceEvidenceGrant? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final documentId = raw['documentId'];
    final url = raw['downloadUrl'];
    final contentType = raw['contentType'];
    final sizeBytes = raw['sizeBytes'];
    final contentHash = raw['contentHash'];
    final expiresAtMs = raw['expiresAtMs'];
    if (documentId is! String || documentId.isEmpty) return null;
    if (url is! String || url.isEmpty) return null;
    if (contentType is! String || contentType.isEmpty) return null;
    if (sizeBytes is! int || sizeBytes <= 0) return null;
    if (contentHash is! String || contentHash.isEmpty) return null;
    if (expiresAtMs is! int || expiresAtMs <= 0) return null;
    return ComplianceEvidenceGrant(
      documentId: documentId,
      downloadUrl: url,
      contentType: contentType,
      sizeBytes: sizeBytes,
      contentHash: contentHash,
      expiresAtMs: expiresAtMs,
    );
  }
}

class ComplianceReviewService {
  ComplianceReviewService({
    FirebaseFunctions? functions,
    MarketplaceFunctionCaller? callableInvoker,
    FirebaseFirestore? firestore,
  }) : _callableInvoker = callableInvoker ?? _defaultInvoker(functions),
       _firestoreOverride = firestore;

  static MarketplaceFunctionCaller _defaultInvoker(
    FirebaseFunctions? functions,
  ) {
    final resolved =
        functions ??
        FirebaseFunctions.instanceFor(region: marketplaceFunctionsRegion);
    return (name, data) async {
      final result = await resolved.httpsCallable(name).call(data);
      return result.data;
    };
  }

  final MarketplaceFunctionCaller _callableInvoker;
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore? _db;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? (_db ??= FirebaseFirestore.instance);

  /// The canonical pending-review queue.
  ///
  /// Server-side filtered on `status == pending_review` — never a broad read
  /// narrowed on the client — and ordered by `uploadedAt` so the oldest
  /// submission is reviewed first. Backed by the composite index
  /// (`status` ASC, `uploadedAt` ASC); Firestore appends `__name__` ASC to
  /// every composite index, which is what makes tied `uploadedAt` values
  /// order deterministically and cursor pagination stable.
  Query<Map<String, dynamic>> pendingReviewQuery({int limit = 25}) {
    return _firestore
        .collection('complianceDocuments')
        .where(
          'status',
          isEqualTo: ComplianceDocumentStatus.pendingReview.wireValue,
        )
        .orderBy('uploadedAt')
        .limit(limit);
  }

  Stream<List<ComplianceReviewItem>> watchPendingReview({int limit = 25}) {
    return pendingReviewQuery(limit: limit).snapshots().map(
      (snap) => snap.docs
          .map((d) => ComplianceReviewItem.fromSnapshot(d.id, d.data()))
          .toList(growable: false),
    );
  }

  /// Canonical state for one document. The review screen reads this rather
  /// than trusting the queue row it was opened from, so a decision another
  /// admin already took is visible immediately.
  Stream<ComplianceReviewItem?> watchDocument(String documentId) {
    return _firestore
        .collection('complianceDocuments')
        .doc(documentId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return ComplianceReviewItem.fromSnapshot(
            documentId,
            snap.data() ?? const {},
          );
        });
  }

  /// Obtains a short-lived authorization to view this document's evidence.
  /// The path, bucket and binding are all resolved server-side; this client
  /// sends only the document id.
  Future<ComplianceEvidenceGrant> requestEvidence(String documentId) async {
    try {
      final raw = await _callableInvoker('getComplianceDocumentEvidence', {
        'documentId': documentId,
      });
      final grant = ComplianceEvidenceGrant.tryParse(raw);
      if (grant == null || grant.documentId != documentId) {
        throw const ComplianceReviewException(
          ComplianceReviewFailureKind.evidenceUnavailable,
        );
      }
      return grant;
    } on ComplianceReviewException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ComplianceReviewException(_mapFailure(error, evidence: true));
    } catch (_) {
      throw const ComplianceReviewException(
        ComplianceReviewFailureKind.generic,
      );
    }
  }

  /// `pending_review -> approved`. The server re-reads the document inside a
  /// transaction, so it — not this client — decides whether the transition is
  /// still legal.
  Future<ComplianceDocumentStatus> approve(String documentId) =>
      _decide(documentId: documentId, decision: 'approve');

  /// `pending_review -> rejected`. [rejectionReason] is the frozen free-text
  /// field; there is no category taxonomy and none is invented.
  /// `async` deliberately: a synchronous throw from a Future-returning method
  /// escapes before the Future exists, so callers using `.catchError` or
  /// `expectLater(..., throwsA(...))` never see it. Every failure from this
  /// method arrives as a rejected Future, like every other failure here.
  Future<ComplianceDocumentStatus> reject({
    required String documentId,
    required String rejectionReason,
  }) async {
    // Client-side guard mirroring the server's own normalization. The server
    // remains authoritative; this only stops an obviously blank submission
    // from making a round trip.
    if (rejectionReason.trim().isEmpty) {
      throw const ComplianceReviewException(
        ComplianceReviewFailureKind.invalidInput,
      );
    }
    return _decide(
      documentId: documentId,
      decision: 'reject',
      rejectionReason: rejectionReason,
    );
  }

  Future<ComplianceDocumentStatus> _decide({
    required String documentId,
    required String decision,
    String? rejectionReason,
  }) async {
    try {
      // Built explicitly rather than with a conditional element so the
      // approve request provably carries NO rejectionReason key at all —
      // the server refuses one on an approval, and must keep doing so.
      final payload = <String, dynamic>{
        'documentId': documentId,
        'decision': decision,
      };
      if (rejectionReason != null) {
        payload['rejectionReason'] = rejectionReason;
      }
      final raw = await _callableInvoker('reviewComplianceDocument', payload);
      if (raw is! Map) {
        throw const ComplianceReviewException(
          ComplianceReviewFailureKind.unavailableRetry,
        );
      }
      final status = complianceDocumentStatusFromWire(raw['status']);
      // A response that does not name a final status is never read as
      // success — the UI must not claim a decision the server did not state.
      if (status != ComplianceDocumentStatus.approved &&
          status != ComplianceDocumentStatus.rejected) {
        throw const ComplianceReviewException(
          ComplianceReviewFailureKind.unavailableRetry,
        );
      }
      return status!;
    } on ComplianceReviewException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ComplianceReviewException(_mapFailure(error));
    } catch (_) {
      throw const ComplianceReviewException(
        ComplianceReviewFailureKind.generic,
      );
    }
  }

  ComplianceReviewFailureKind _mapFailure(
    FirebaseFunctionsException error, {
    bool evidence = false,
  }) {
    switch (error.code) {
      case 'unauthenticated':
        return ComplianceReviewFailureKind.unauthenticated;
      case 'permission-denied':
        return ComplianceReviewFailureKind.notAdmin;
      case 'not-found':
        return ComplianceReviewFailureKind.notFound;
      case 'failed-precondition':
        if (evidence) {
          return ComplianceReviewFailureKind.evidenceUnavailable;
        }
        // The server says the transition is no longer legal, or the same
        // document was already decided differently. Either way this admin's
        // view is stale and canonical state must win.
        final message = error.message ?? '';
        return message.contains('idempotency_conflict')
            ? ComplianceReviewFailureKind.conflict
            : ComplianceReviewFailureKind.staleDecision;
      case 'invalid-argument':
        return ComplianceReviewFailureKind.invalidInput;
      case 'unavailable':
      case 'deadline-exceeded':
        return ComplianceReviewFailureKind.unavailableRetry;
      default:
        return ComplianceReviewFailureKind.generic;
    }
  }
}
