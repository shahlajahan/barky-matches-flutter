import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/compliance_evidence_service.dart';

/// Marketplace Revision 30 §J Slice 3 — the seller evidence upload surface.
///
/// What this screen is, exactly: a way for the owner of one business to hand
/// one document to the server for review. It creates a server session first
/// and writes only to the path that session names. It shows the frozen
/// lifecycle honestly, and it says plainly — in a notice that is always
/// visible, not buried behind a success state — that submitting is not
/// approval (Revision 30 §I).
///
/// What this screen deliberately is NOT: it renders no approval, review,
/// effectiveness, product-linkage or publication affordance of any kind.
/// Those belong to slices 4, 5 and 7 and are not anticipated here. No state
/// this widget can reach describes a document as approved, verified,
/// effective or publication-eligible, and a test asserts that.
///
/// `category_compliance_evidence` is never offered: Revision 30 §D assigns it
/// to no relationship, the policy is unresolved, and the picker is built from
/// [selectableDocumentTypesFor] rather than from the enum's own values.
typedef CompliancePickedFile = ({
  String filename,
  String mimeType,
  Uint8List bytes,
});

/// Injectable so tests drive the flow without a platform file picker.
typedef CompliancePickFile = Future<CompliancePickedFile?> Function();

class ComplianceEvidenceUploadPage extends StatefulWidget {
  const ComplianceEvidenceUploadPage({
    super.key,
    required this.businessId,
    this.service,
    this.pickFile,
    this.onClose,
  });

  /// The business the authenticated owner selected. Every request carries
  /// this exact value; the server independently re-derives ownership and the
  /// generation binding from it and refuses anything else.
  final String businessId;

  final ComplianceEvidenceService? service;
  final CompliancePickFile? pickFile;
  final VoidCallback? onClose;

  @override
  State<ComplianceEvidenceUploadPage> createState() =>
      _ComplianceEvidenceUploadPageState();
}

class _ComplianceEvidenceUploadPageState
    extends State<ComplianceEvidenceUploadPage> {
  late final ComplianceEvidenceService _service =
      widget.service ?? ComplianceEvidenceService();

  SellerRelationship? _relationship;
  ComplianceDocumentType? _documentType;
  CompliancePickedFile? _picked;

  ComplianceEvidenceStage _stage = ComplianceEvidenceStage.idle;
  ComplianceEvidenceFailureKind? _failure;

  /// One key per upload ATTEMPT, reused across retries of that attempt so the
  /// server's own idempotency contract recognises them as the same request.
  /// Minted when an attempt starts, cleared only when it truly ends.
  String? _attemptKey;

  /// Second latch against re-entrant submission.
  ///
  /// The PRIMARY guard is the synchronous `_stage = requestingSession`
  /// assignment in [_submit], made before the first `await`: `_canSubmit`
  /// reads it immediately, so a second tap in the same frame — before any
  /// rebuild can disable the button — already returns. A mutation test
  /// confirms that: deferring that assignment until after the session call
  /// makes three same-frame taps create two sessions and fails the suite.
  ///
  /// This flag is deliberately redundant with it, and is stated as redundant
  /// rather than left looking load-bearing: removing it alone changes no
  /// observable behaviour today. It is kept because it is the guard that
  /// survives a future refactor which moves, batches or defers that setState
  /// — exactly the refactor the mutation above shows would otherwise orphan
  /// a quarantine object per extra tap.
  bool _submitting = false;

  /// The server's own view of this business's most recent session. It is what
  /// makes §I's "state is restored after navigation and app restart" true:
  /// without it, coming back to this screen would show `idle` while an upload
  /// was still being scanned, and would then permit the blind re-upload §I
  /// forbids. Read-only — the client can never write these documents.
  StreamSubscription<String?>? _serverStatusSub;
  String? _serverStatus;

  @override
  void initState() {
    super.initState();
    _serverStatusSub = _service
        .watchLatestSessionStatus(widget.businessId)
        .listen(
          (status) {
            if (!mounted) return;
            setState(() => _serverStatus = status);
          },
          // A denied or unavailable read must never be reported as "no
          // upload in progress" — that would re-open blind re-upload. It
          // simply leaves the local stage authoritative.
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    _serverStatusSub?.cancel();
    super.dispose();
  }

  /// The stage actually shown. The server's view wins whenever it reports
  /// work still in flight or a settled outcome, so a locally-`idle` screen
  /// can never contradict a live session.
  ComplianceEvidenceStage get _effectiveStage {
    final fromServer = stageForSessionStatus(_serverStatus);
    if (_stage == ComplianceEvidenceStage.requestingSession ||
        _stage == ComplianceEvidenceStage.uploading) {
      return _stage;
    }
    if (fromServer != ComplianceEvidenceStage.idle) return fromServer;
    return _stage;
  }

  bool get _inFlight {
    final stage = _effectiveStage;
    return _submitting ||
        stage == ComplianceEvidenceStage.requestingSession ||
        stage == ComplianceEvidenceStage.uploading ||
        stage == ComplianceEvidenceStage.processing ||
        // A session the server still holds open authorizes exactly one
        // object write. Starting another now would orphan one of them.
        complianceInFlightSessionStatuses.contains(_serverStatus);
  }

  bool get _canSubmit =>
      !_inFlight &&
      _relationship != null &&
      _documentType != null &&
      _picked != null;

  void _selectRelationship(SellerRelationship? value) {
    if (_inFlight) return;
    setState(() {
      _relationship = value;
      // The previously chosen type may not be listed for the new
      // relationship; never carry a now-impermissible pair forward.
      final permitted = value == null
          ? const <ComplianceDocumentType>[]
          : selectableDocumentTypesFor(value);
      if (_documentType != null && !permitted.contains(_documentType)) {
        _documentType = null;
      }
      _failure = null;
    });
  }

  Future<void> _pick() async {
    if (_inFlight) return;
    final picker = widget.pickFile;
    if (picker == null) return;
    final picked = await picker();
    if (!mounted || picked == null) return;
    setState(() {
      _picked = picked;
      _failure = null;
    });
  }

  Future<void> _submit() async {
    // Guard first, state second: the check and the set must not be separated
    // by an await, or two taps in the same frame both pass it.
    if (_submitting || !_canSubmit) return;
    _submitting = true;

    final relationship = _relationship!;
    final documentType = _documentType!;
    final file = _picked!;
    // Retries of THIS attempt reuse the key; a new attempt mints a new one.
    _attemptKey ??= generateComplianceUploadIdempotencyKey();

    setState(() {
      _stage = ComplianceEvidenceStage.requestingSession;
      _failure = null;
    });

    try {
      final session = await _service.createUploadSession(
        businessId: widget.businessId,
        sellerRelationship: relationship,
        documentType: documentType,
        originalFilename: file.filename,
        declaredMimeType: file.mimeType,
        declaredSizeBytes: file.bytes.length,
        clientIdempotencyKey: _attemptKey!,
      );

      if (!mounted) return;
      setState(() => _stage = ComplianceEvidenceStage.uploading);

      // The ONLY write this screen performs, and only to the path the server
      // chose. There is no branch that uploads without a session.
      await _service.uploadToSession(
        session: session,
        bytes: file.bytes,
        contentType: file.mimeType,
      );

      if (!mounted) return;
      setState(() {
        // Uploaded is not reviewed and is certainly not approved: the server
        // still has to validate, scan and promote.
        _stage = ComplianceEvidenceStage.processing;
        _attemptKey = null;
      });
    } on ComplianceEvidenceException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.kind;
        _stage = ComplianceEvidenceStage.idle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = ComplianceEvidenceFailureKind.generic;
        _stage = ComplianceEvidenceStage.idle;
      });
    } finally {
      _submitting = false;
    }
  }

  String _documentTypeLabel(AppLocalizations l10n, ComplianceDocumentType t) {
    switch (t) {
      case ComplianceDocumentType.purchaseInvoice:
        return l10n.complianceDocumentTypePurchaseInvoice;
      case ComplianceDocumentType.supplierAgreement:
        return l10n.complianceDocumentTypeSupplierAgreement;
      case ComplianceDocumentType.authorizationLetter:
        return l10n.complianceDocumentTypeAuthorizationLetter;
      case ComplianceDocumentType.dealershipDistributionAgreement:
        return l10n.complianceDocumentTypeDealershipDistributionAgreement;
      case ComplianceDocumentType.trademarkEvidence:
        return l10n.complianceDocumentTypeTrademarkEvidence;
      case ComplianceDocumentType.manufacturerEvidence:
        return l10n.complianceDocumentTypeManufacturerEvidence;
      case ComplianceDocumentType.importerEvidence:
        return l10n.complianceDocumentTypeImporterEvidence;
      case ComplianceDocumentType.categoryComplianceEvidence:
        // Unreachable by construction: this type is never placed in a picker
        // (selectableDocumentTypesFor excludes it) and the service refuses it
        // even if called programmatically. Returning the generic label rather
        // than throwing keeps the switch total without inventing a policy or
        // surfacing a selectable name for it.
        return l10n.complianceEvidenceDocumentTypeLabel;
    }
  }

  String _relationshipLabel(AppLocalizations l10n, SellerRelationship r) {
    switch (r) {
      case SellerRelationship.brandOwner:
        return l10n.sellerRelationshipBrandOwner;
      case SellerRelationship.manufacturer:
        return l10n.sellerRelationshipManufacturer;
      case SellerRelationship.authorizedDistributor:
        return l10n.sellerRelationshipAuthorizedDistributor;
      case SellerRelationship.authorizedDealer:
        return l10n.sellerRelationshipAuthorizedDealer;
      case SellerRelationship.importer:
        return l10n.sellerRelationshipImporter;
      case SellerRelationship.reseller:
        return l10n.sellerRelationshipReseller;
    }
  }

  String? _failureMessage(AppLocalizations l10n) {
    switch (_failure) {
      case null:
        return null;
      case ComplianceEvidenceFailureKind.unauthenticated:
      case ComplianceEvidenceFailureKind.permissionDenied:
        // One message for both: the server refuses to distinguish an absent
        // business from a non-owned one, and this screen must not either.
        return l10n.accessDenied;
      case ComplianceEvidenceFailureKind.notEnabledForBusiness:
      case ComplianceEvidenceFailureKind.documentTypePolicyUnresolved:
        return l10n.complianceEvidenceErrorNotEnabled;
      case ComplianceEvidenceFailureKind.invalidSubmission:
        return l10n.complianceEvidenceErrorInvalidSubmission;
      case ComplianceEvidenceFailureKind.sessionConflict:
        return l10n.complianceEvidenceErrorSessionConflict;
      case ComplianceEvidenceFailureKind.uploadFailed:
        return l10n.complianceEvidenceErrorUploadFailed;
      case ComplianceEvidenceFailureKind.unavailableRetry:
        return l10n.networkErrorTryAgain;
      case ComplianceEvidenceFailureKind.generic:
        return l10n.somethingWentWrong;
    }
  }

  String? _stageMessage(AppLocalizations l10n) {
    switch (_effectiveStage) {
      case ComplianceEvidenceStage.idle:
        return null;
      case ComplianceEvidenceStage.requestingSession:
        return l10n.complianceEvidenceStageRequestingSession;
      case ComplianceEvidenceStage.uploading:
        return l10n.complianceEvidenceStageUploading;
      case ComplianceEvidenceStage.processing:
        return l10n.complianceEvidenceStageProcessing;
      case ComplianceEvidenceStage.awaitingReview:
        return l10n.complianceEvidenceStageAwaitingReview;
      case ComplianceEvidenceStage.failedRetryable:
        return l10n.complianceEvidenceStageFailedRetryable;
      case ComplianceEvidenceStage.failedTerminal:
        return l10n.complianceEvidenceStageFailedTerminal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final permitted = _relationship == null
        ? const <ComplianceDocumentType>[]
        : selectableDocumentTypesFor(_relationship!);
    final stageMessage = _stageMessage(l10n);
    final failureMessage = _failureMessage(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.complianceEvidenceTitle),
        leading: widget.onClose == null
            ? null
            : IconButton(
                key: const Key('complianceEvidenceCloseButton'),
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Always visible, never conditional on a success state.
            Card(
              key: const Key('complianceEvidenceNotApprovalNotice'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l10n.complianceEvidenceNotApprovalNotice),
              ),
            ),
            const SizedBox(height: 16),

            Text(l10n.complianceEvidenceRelationshipLabel),
            const SizedBox(height: 8),
            DropdownButtonFormField<SellerRelationship>(
              key: const Key('complianceEvidenceRelationshipDropdown'),
              initialValue: _relationship,
              items: SellerRelationship.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(_relationshipLabel(l10n, r)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _inFlight ? null : _selectRelationship,
            ),

            if (_relationship != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.complianceEvidenceRequirementHint,
                key: const Key('complianceEvidenceRequirementHint'),
              ),
              const SizedBox(height: 8),
              Text(l10n.complianceEvidenceDocumentTypeLabel),
              const SizedBox(height: 8),
              DropdownButtonFormField<ComplianceDocumentType>(
                key: const Key('complianceEvidenceDocumentTypeDropdown'),
                initialValue: _documentType,
                // Built from the frozen matrix only — never from
                // ComplianceDocumentType.values.
                items: permitted
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_documentTypeLabel(l10n, t)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _inFlight
                    ? null
                    : (value) => setState(() {
                        _documentType = value;
                        _failure = null;
                      }),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              l10n.complianceEvidenceFormatsHint,
              key: const Key('complianceEvidenceFormatsHint'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('complianceEvidencePickButton'),
              onPressed: _inFlight ? null : _pick,
              child: Text(_picked?.filename ?? l10n.complianceEvidencePickFile),
            ),

            const SizedBox(height: 16),
            FilledButton(
              key: const Key('complianceEvidenceSubmitButton'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(l10n.complianceEvidenceSubmit),
            ),

            if (_inFlight) ...[
              const SizedBox(height: 12),
              Text(
                l10n.complianceEvidenceUploadInProgressNotice,
                key: const Key('complianceEvidenceInProgressNotice'),
              ),
            ],

            if (stageMessage != null) ...[
              const SizedBox(height: 12),
              Text(stageMessage, key: const Key('complianceEvidenceStageText')),
            ],

            if (failureMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                failureMessage,
                key: const Key('complianceEvidenceFailureText'),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              l10n.complianceEvidencePrivacyNotice,
              key: const Key('complianceEvidencePrivacyNotice'),
            ),
          ],
        ),
      ),
    );
  }
}
