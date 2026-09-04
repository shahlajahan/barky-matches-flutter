import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller, marketplaceFunctionsRegion;

/// Marketplace Revision 30 §J Slice 3 — the seller-facing half of the
/// compliance evidence intake.
///
/// This service consumes the already-committed Slice 2 backend exactly as it
/// is. It creates nothing server-side of its own: every upload is authorized
/// by `createComplianceUploadSession`, and the object is written **only** to
/// the exact `objectPath` that call returns. There is no client-chosen path,
/// no direct write, and no fallback that would upload without a session.
///
/// Nothing here approves, verifies or publishes anything. A successful
/// upload means one thing only: bytes reached quarantine. Revision 30 §C
/// ("a dropdown selection is never evidence") and §G (the document is
/// created at `clean` and only an Admin-SDK server operation may move it)
/// both remain untouched by anything in this file.

/// The exact declared relationship values the backend accepts
/// (`SELLER_RELATIONSHIP`, frozen in
/// `functions/src/marketplace/compliance/complianceConstants.js`).
enum SellerRelationship {
  brandOwner('brand_owner'),
  manufacturer('manufacturer'),
  authorizedDistributor('authorized_distributor'),
  authorizedDealer('authorized_dealer'),
  importer('importer'),
  reseller('reseller');

  const SellerRelationship(this.wireValue);
  final String wireValue;
}

/// The exact document types the backend recognises
/// (`COMPLIANCE_DOCUMENT_TYPE`).
///
/// `categoryComplianceEvidence` is deliberately declared here so the client
/// vocabulary matches the server's, and is just as deliberately absent from
/// [complianceIntakeEvidenceMatrix]: Revision 30 §D assigns it to no
/// relationship, so the backend rejects it with
/// `document_type_policy_unresolved`. It must never be offered to a seller —
/// see [selectableDocumentTypesFor], which is the only list the UI may use.
enum ComplianceDocumentType {
  purchaseInvoice('purchase_invoice'),
  supplierAgreement('supplier_agreement'),
  authorizationLetter('authorization_letter'),
  dealershipDistributionAgreement('dealership_distribution_agreement'),
  trademarkEvidence('trademark_evidence'),
  manufacturerEvidence('manufacturer_evidence'),
  importerEvidence('importer_evidence'),
  categoryComplianceEvidence('category_compliance_evidence');

  const ComplianceDocumentType(this.wireValue);
  final String wireValue;
}

/// Client mirror of `COMPLIANCE_INTAKE_EVIDENCE_MATRIX`, transcribed from the
/// same Revision 30 §D table the server uses. It exists so the seller is
/// offered only combinations the server will accept — never to decide
/// anything. The server re-derives this check independently and remains the
/// only authority; a divergence here can narrow what the UI offers but can
/// never widen what the server permits.
///
/// Order matters for display: each row's first entry is that relationship's
/// **minimum** evidence type as §D names it, and the remainder are its listed
/// alternatives.
const Map<SellerRelationship, List<ComplianceDocumentType>>
complianceIntakeEvidenceMatrix = {
  SellerRelationship.brandOwner: [
    ComplianceDocumentType.trademarkEvidence,
    ComplianceDocumentType.manufacturerEvidence,
  ],
  SellerRelationship.manufacturer: [
    ComplianceDocumentType.manufacturerEvidence,
    ComplianceDocumentType.trademarkEvidence,
  ],
  SellerRelationship.authorizedDistributor: [
    ComplianceDocumentType.dealershipDistributionAgreement,
    ComplianceDocumentType.authorizationLetter,
  ],
  SellerRelationship.authorizedDealer: [
    ComplianceDocumentType.authorizationLetter,
    ComplianceDocumentType.dealershipDistributionAgreement,
  ],
  SellerRelationship.importer: [
    ComplianceDocumentType.importerEvidence,
    ComplianceDocumentType.purchaseInvoice,
    ComplianceDocumentType.supplierAgreement,
  ],
  SellerRelationship.reseller: [
    ComplianceDocumentType.purchaseInvoice,
    ComplianceDocumentType.supplierAgreement,
  ],
};

/// Document types no relationship may submit, because Revision 30 §D lists
/// them in no row. Kept as its own named constant so the exclusion is an
/// explicit, testable decision rather than an accident of the matrix.
const Set<ComplianceDocumentType> unresolvedPolicyDocumentTypes = {
  ComplianceDocumentType.categoryComplianceEvidence,
};

/// The ONLY list the UI may render for a relationship. Never iterate
/// [ComplianceDocumentType.values] in a picker.
List<ComplianceDocumentType> selectableDocumentTypesFor(
  SellerRelationship relationship,
) {
  final permitted = complianceIntakeEvidenceMatrix[relationship] ?? const [];
  return permitted
      .where((type) => !unresolvedPolicyDocumentTypes.contains(type))
      .toList(growable: false);
}

/// Exactly `COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES`.
const List<String> complianceAllowedMimeTypes = [
  'application/pdf',
  'image/jpeg',
  'image/png',
];

/// Exactly `COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES` (15 MiB).
const int complianceMaxUploadSizeBytes = 15 * 1024 * 1024;

/// Exactly `COMPLIANCE_UPLOAD_SESSION_MAX_ORIGINAL_FILENAME_LENGTH`.
const int complianceMaxOriginalFilenameLength = 200;

/// A typed classification of why an evidence upload did not complete.
///
/// Deliberately coarse where the server is deliberately coarse: the server
/// returns one indistinguishable `permission-denied` for an absent business,
/// a non-owned business and a malformed owner, and this enum preserves that
/// — the client must never reconstruct a distinction the server refused to
/// make.
enum ComplianceEvidenceFailureKind {
  /// Not signed in.
  unauthenticated,

  /// The caller does not own this business — or it does not exist. One
  /// outcome, by server design.
  permissionDenied,

  /// Compliance uploads are not enabled for this business yet (the
  /// deny-by-default canary), or the business is not eligible.
  notEnabledForBusiness,

  /// The chosen document type is not yet enabled for upload at all —
  /// Revision 30 §D assigns it to no relationship and the policy is
  /// unresolved. The UI must never reach this: it does not offer the type.
  documentTypePolicyUnresolved,

  /// The file or the declared relationship/type pair was rejected.
  invalidSubmission,

  /// A session already exists for this attempt and is no longer reusable,
  /// or a different request reused the same idempotency key.
  sessionConflict,

  /// The Storage write itself failed after a session was created.
  uploadFailed,

  /// Network/backend unavailability — safe to retry.
  unavailableRetry,

  /// Anything else.
  generic,
}

class ComplianceEvidenceException implements Exception {
  final ComplianceEvidenceFailureKind kind;
  const ComplianceEvidenceException(this.kind);

  @override
  String toString() => 'ComplianceEvidenceException($kind)';
}

/// The server-created session, exactly as `createComplianceUploadSession`
/// returns it. `objectPath` is authoritative and is the only path this
/// client ever writes to.
class ComplianceUploadSession {
  const ComplianceUploadSession({
    required this.sessionId,
    required this.objectPath,
    required this.maxSizeBytes,
    required this.allowedMimeTypes,
    required this.status,
  });

  final String sessionId;
  final String objectPath;
  final int maxSizeBytes;
  final List<String> allowedMimeTypes;
  final String status;

  static ComplianceUploadSession? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final sessionId = raw['sessionId'];
    final objectPath = raw['objectPath'];
    final maxSizeBytes = raw['maxSizeBytes'];
    final status = raw['status'];
    final allowed = raw['allowedMimeTypes'];
    if (sessionId is! String || sessionId.isEmpty) return null;
    if (objectPath is! String || objectPath.isEmpty) return null;
    if (maxSizeBytes is! int || maxSizeBytes <= 0) return null;
    if (status is! String || status.isEmpty) return null;
    if (allowed is! List) return null;
    return ComplianceUploadSession(
      sessionId: sessionId,
      objectPath: objectPath,
      maxSizeBytes: maxSizeBytes,
      allowedMimeTypes: allowed.whereType<String>().toList(growable: false),
      status: status,
    );
  }
}

/// One reading of the seller's latest session: its status, and the canonical
/// promoted document id if promotion has committed.
class ComplianceSessionSnapshot {
  const ComplianceSessionSnapshot({
    required this.status,
    required this.documentId,
    this.declaredSellerRelationship,
  });

  /// `null` only when no session record exists at all.
  final String? status;

  /// The server-written `consumedByDocumentId`, present only after promotion.
  final String? documentId;

  /// The relationship the server recorded at intake. Submission must use
  /// THIS value, not a fresh dropdown choice: the document has to be
  /// submitted under the relationship its own upload was authorized for, and
  /// after navigation or a restart the seller's local selection is gone.
  final SellerRelationship? declaredSellerRelationship;
}

/// Parses a stored wire value back to the enum, or null if unrecognized.
/// Unrecognized never falls back to a default — that would submit a document
/// under a relationship nobody declared.
SellerRelationship? sellerRelationshipFromWire(Object? value) {
  if (value is! String) return null;
  for (final r in SellerRelationship.values) {
    if (r.wireValue == value) return r;
  }
  return null;
}

/// The frozen upload-session lifecycle, as the seller sees it. These map
/// one-to-one onto `COMPLIANCE_UPLOAD_SESSION_STATUS`; no state is invented,
/// and none of them means "approved".
enum ComplianceEvidenceStage {
  /// No upload started for this business yet.
  idle,

  /// Requesting the server session.
  requestingSession,

  /// Writing bytes to the session's quarantine object.
  uploading,

  /// Uploaded; the server is validating, scanning or promoting. The seller
  /// must not re-upload while this is true.
  processing,

  /// The scan and promotion committed, so a `complianceDocuments` record
  /// exists at status `clean`. It has NOT been submitted for review yet:
  /// Revision 30 §G's lifecycle is `clean -> pending_review -> approved |
  /// rejected`, and only `submitComplianceDocument` performs the first
  /// transition. The seller still has an action to take.
  awaitingSubmission,

  /// The document is genuinely at `pending_review`. Explicitly NOT approval.
  awaitingReview,

  /// The document has left the seller's hands entirely — a recognized status
  /// beyond `pending_review`. Slice 3 cannot produce one and deliberately
  /// presents no review OUTCOME: rendering approved/rejected/revoked copy is
  /// Slice 4's admin-review surface, not this screen's.
  reviewClosed,

  /// FAIL-CLOSED. The server reported a status this client does not
  /// recognise — a newly introduced state, a malformed value, or a missing
  /// one on a record that does exist. Never treated as idle, fresh, ready or
  /// retryable: every control is disabled until the client understands the
  /// state again.
  unknownState,

  /// A terminal failure the seller may retry with a fresh file.
  failedRetryable,

  /// A terminal failure the seller may not simply retry (infected file).
  failedTerminal,
}

/// The subset of session statuses that mean work is still in flight, so a
/// second upload must be suppressed rather than silently orphaning an object.
const Set<String> complianceInFlightSessionStatuses = {
  'upload_authorized',
  'uploaded',
  'validating',
  'scan_pending',
  'promotion_pending',
};

/// Sentinel emitted when a session record exists but its `status` field is
/// absent or not a string. Distinct from `null`, which means "this business
/// has no session at all" — the genuinely fresh case, where controls must
/// stay enabled or the feature is unusable.
const String complianceUnrecognizedStatus = '__unrecognized__';

/// Maps a raw session status onto the stage the UI shows.
///
/// FAIL-CLOSED BY CONSTRUCTION. `null` — and only `null` — means "no session
/// exists" and yields `idle`. Every other unrecognized value, including a
/// status a future server release introduces, yields [ComplianceEvidenceStage
/// .unknownState], which disables every control. A `default:` arm that
/// returned `idle` would silently re-open blind upload the moment the
/// backend gained a state, so it does not exist here.
ComplianceEvidenceStage stageForSessionStatus(String? status) {
  if (status == null) return ComplianceEvidenceStage.idle;
  switch (status) {
    case 'upload_authorized':
    case 'uploaded':
    case 'validating':
    case 'scan_pending':
    case 'promotion_pending':
      return ComplianceEvidenceStage.processing;
    case 'consumed':
      // `consumed` is a SESSION status. It means the upload session was spent
      // and a document was created at `clean` — it does NOT mean the document
      // is `pending_review`. The document's own status decides that, and the
      // page reads it separately. Mapping this to awaitingReview would tell
      // the seller their document is queued for review when in fact nobody
      // has been asked to review it.
      return ComplianceEvidenceStage.awaitingSubmission;
    case 'infected':
      return ComplianceEvidenceStage.failedTerminal;
    case 'expired':
    case 'cancelled':
    case 'validation_failed':
    case 'scan_failed':
      return ComplianceEvidenceStage.failedRetryable;
    default:
      return ComplianceEvidenceStage.unknownState;
  }
}

/// Maps a raw `complianceDocuments` status onto the stage the UI shows.
/// Same fail-closed discipline: `null` means "no document yet", everything
/// unrecognized disables every control.
ComplianceEvidenceStage stageForDocumentStatus(String? status) {
  if (status == null) return ComplianceEvidenceStage.idle;
  switch (status) {
    case 'clean':
      return ComplianceEvidenceStage.awaitingSubmission;
    case 'pending_review':
      return ComplianceEvidenceStage.awaitingReview;
    case 'approved':
    case 'rejected':
    case 'revoked':
    case 'expired':
    case 'superseded':
      return ComplianceEvidenceStage.reviewClosed;
    default:
      return ComplianceEvidenceStage.unknownState;
  }
}

/// The only stages in which the seller may start a NEW upload. A positive
/// allowlist, never a "not in this deny-list" test: a stage added later is
/// disabled until it is explicitly enumerated here.
const Set<ComplianceEvidenceStage> complianceUploadEnabledStages = {
  ComplianceEvidenceStage.idle,
  ComplianceEvidenceStage.failedRetryable,
};

/// The only stage in which the seller may submit a promoted document for
/// review. Likewise a positive allowlist.
const Set<ComplianceEvidenceStage> complianceSubmitEnabledStages = {
  ComplianceEvidenceStage.awaitingSubmission,
};

/// Uploads bytes to an already-authorized session path. Injectable so widget
/// tests never touch real Storage.
typedef ComplianceObjectUploader =
    Future<void> Function(
      String objectPath,
      Uint8List bytes,
      String contentType,
    );

class ComplianceEvidenceService {
  ComplianceEvidenceService({
    FirebaseFunctions? functions,
    MarketplaceFunctionCaller? callableInvoker,
    ComplianceObjectUploader? uploader,
    FirebaseFirestore? firestore,
  }) : _callableInvoker = callableInvoker ?? _defaultInvoker(functions),
       _uploader = uploader ?? _defaultUploader,
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

  static Future<void> _defaultUploader(
    String objectPath,
    Uint8List bytes,
    String contentType,
  ) async {
    await FirebaseStorage.instance
        .ref()
        .child(objectPath)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }

  final MarketplaceFunctionCaller _callableInvoker;
  final ComplianceObjectUploader _uploader;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore? _db;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? (_db ??= FirebaseFirestore.instance);

  /// Requests a server session. The returned `objectPath` is the only place
  /// the caller may write.
  Future<ComplianceUploadSession> createUploadSession({
    required String businessId,
    required SellerRelationship sellerRelationship,
    required ComplianceDocumentType documentType,
    required String originalFilename,
    required String declaredMimeType,
    required int declaredSizeBytes,
    required String clientIdempotencyKey,
  }) async {
    // Defence in depth: the UI never offers an unresolved type, and the
    // server rejects it anyway. Refusing here as well means no client code
    // path — not even a programmatic one — can request a session for it.
    if (unresolvedPolicyDocumentTypes.contains(documentType) ||
        !(complianceIntakeEvidenceMatrix[sellerRelationship] ?? const [])
            .contains(documentType)) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.invalidSubmission,
      );
    }
    try {
      final raw = await _callableInvoker('createComplianceUploadSession', {
        'businessId': businessId,
        'originalFilename': originalFilename,
        'declaredMimeType': declaredMimeType,
        'declaredSizeBytes': declaredSizeBytes,
        'documentType': documentType.wireValue,
        'sellerRelationship': sellerRelationship.wireValue,
        'clientIdempotencyKey': clientIdempotencyKey,
      });
      final session = ComplianceUploadSession.tryParse(raw);
      if (session == null) {
        throw const ComplianceEvidenceException(
          ComplianceEvidenceFailureKind.unavailableRetry,
        );
      }
      return session;
    } on ComplianceEvidenceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ComplianceEvidenceException(_mapFailure(error));
    } catch (_) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.generic,
      );
    }
  }

  /// Writes the bytes to the session's own path — never to a path this
  /// client composed.
  Future<void> uploadToSession({
    required ComplianceUploadSession session,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > session.maxSizeBytes) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.invalidSubmission,
      );
    }
    if (!session.allowedMimeTypes.contains(contentType)) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.invalidSubmission,
      );
    }
    try {
      await _uploader(session.objectPath, bytes, contentType);
    } catch (_) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.uploadFailed,
      );
    }
  }

  /// The seller's own most recent session for this business, used to restore
  /// state after navigation or an app restart and to suppress a blind
  /// re-upload while one is still in flight. Read-only; the client can never
  /// write these documents.
  ///
  /// A record whose `status` is absent or not a string yields
  /// [complianceUnrecognizedStatus], never `null` — `null` is reserved for
  /// "no session exists", the one case in which controls stay enabled.
  Stream<ComplianceSessionSnapshot> watchLatestSession(String businessId) {
    return _firestore
        .collection('complianceUploadSessions')
        .where('businessId', isEqualTo: businessId)
        .orderBy('issuedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) {
            return const ComplianceSessionSnapshot(
              status: null,
              documentId: null,
            );
          }
          final data = snap.docs.first.data();
          final status = data['status'];
          // The canonical promoted document id, and the ONLY identifier this
          // client ever submits. It is written by the server inside the same
          // transaction that sets `status: consumed`, so its presence proves
          // promotion actually committed. The session's own `documentId` is
          // pre-allocated at session creation and exists even when promotion
          // never happened (infected, scan_failed) — submitting that one
          // would name a document that does not exist. Nothing is composed,
          // derived or queried for here.
          final consumedBy = data['consumedByDocumentId'];
          return ComplianceSessionSnapshot(
            status: status is String && status.isNotEmpty
                ? status
                : complianceUnrecognizedStatus,
            documentId: consumedBy is String && consumedBy.isNotEmpty
                ? consumedBy
                : null,
            declaredSellerRelationship: sellerRelationshipFromWire(
              data['declaredSellerRelationship'],
            ),
          );
        });
  }

  /// The seller's own promoted document, read by its canonical id. This is
  /// the authoritative source for whether the document is still `clean` or
  /// has genuinely reached `pending_review`.
  Stream<String?> watchDocumentStatus(String documentId) {
    return _firestore
        .collection('complianceDocuments')
        .doc(documentId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final status = (snap.data() ?? const {})['status'];
          return status is String && status.isNotEmpty
              ? status
              : complianceUnrecognizedStatus;
        });
  }

  /// Submits an already-promoted document for review — the `clean ->
  /// pending_review` transition of Revision 30 §G, performed by the existing
  /// `submitComplianceDocument` callable exactly as that contract is frozen.
  ///
  /// `validUntil` is REQUIRED by the server (its own conservative interim
  /// policy default). That is why submission is an explicit seller action
  /// rather than something this client could fire automatically on promotion:
  /// only the seller knows the document's validity date, and no client may
  /// invent one.
  Future<String> submitDocumentForReview({
    required String documentId,
    required SellerRelationship sellerRelationship,
    required DateTime validUntil,
    DateTime? issuedAt,
    DateTime? validFrom,
  }) async {
    try {
      final raw = await _callableInvoker('submitComplianceDocument', {
        'documentId': documentId,
        'sellerRelationship': sellerRelationship.wireValue,
        'validUntil': validUntil.toUtc().toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt.toUtc().toIso8601String(),
        if (validFrom != null) 'validFrom': validFrom.toUtc().toIso8601String(),
      });
      if (raw is! Map) {
        throw const ComplianceEvidenceException(
          ComplianceEvidenceFailureKind.unavailableRetry,
        );
      }
      final status = raw['status'];
      // A response that does not confirm pending_review is never treated as
      // success: the UI must not claim review is pending on a guess.
      if (status != 'pending_review') {
        throw const ComplianceEvidenceException(
          ComplianceEvidenceFailureKind.unavailableRetry,
        );
      }
      return status as String;
    } on ComplianceEvidenceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ComplianceEvidenceException(_mapFailure(error));
    } catch (_) {
      throw const ComplianceEvidenceException(
        ComplianceEvidenceFailureKind.generic,
      );
    }
  }

  ComplianceEvidenceFailureKind _mapFailure(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map) {
      final reason = details['reasonCode'];
      if (reason == 'document_type_policy_unresolved') {
        return ComplianceEvidenceFailureKind.documentTypePolicyUnresolved;
      }
      if (reason == 'document_type_not_permitted_for_relationship' ||
          reason == 'invalid_seller_relationship' ||
          reason == 'invalid_document_type') {
        return ComplianceEvidenceFailureKind.invalidSubmission;
      }
    }
    switch (error.code) {
      case 'unauthenticated':
        return ComplianceEvidenceFailureKind.unauthenticated;
      case 'permission-denied':
        return ComplianceEvidenceFailureKind.permissionDenied;
      case 'failed-precondition':
        // The canary gate, the generation gate, and an unusable existing
        // session all share this code. `idempotency_conflict` is carried in
        // the message by the server's own contract.
        return error.message != null &&
                error.message!.contains('idempotency_conflict')
            ? ComplianceEvidenceFailureKind.sessionConflict
            : ComplianceEvidenceFailureKind.notEnabledForBusiness;
      case 'already-exists':
        return ComplianceEvidenceFailureKind.sessionConflict;
      case 'invalid-argument':
        return ComplianceEvidenceFailureKind.invalidSubmission;
      case 'resource-exhausted':
        return ComplianceEvidenceFailureKind.sessionConflict;
      case 'unavailable':
      case 'deadline-exceeded':
        return ComplianceEvidenceFailureKind.unavailableRetry;
      default:
        return ComplianceEvidenceFailureKind.generic;
    }
  }
}

/// One key per upload ATTEMPT, reused for every retry of that same attempt so
/// the server's idempotency contract can recognise it. A fresh key is minted
/// only when the seller starts a genuinely new attempt.
String generateComplianceUploadIdempotencyKey() => const Uuid().v4();
