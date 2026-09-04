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
  StreamSubscription<ComplianceSessionSnapshot>? _sessionSub;
  StreamSubscription<String?>? _documentSub;
  ComplianceSessionSnapshot _session = const ComplianceSessionSnapshot(
    status: null,
    documentId: null,
  );

  /// The canonical promoted document id, taken verbatim from the session's
  /// server-written `consumedByDocumentId`. Never composed or guessed.
  String? _documentId;
  String? _documentStatus;

  /// Latch against a duplicate `submitComplianceDocument`. The stream can
  /// re-deliver the same snapshot on any rebuild, reconnection or navigation
  /// return, so the guard cannot live in the stream handler alone.
  bool _submittingForReview = false;

  /// Document ids this screen has already submitted successfully.
  ///
  /// The in-call latch alone is not enough: it releases as soon as the call
  /// returns, while the document's own status may still read `clean` for a
  /// moment (the stream has not delivered `pending_review` yet, or the read
  /// is denied/slow). Every re-delivered snapshot, rebuild or navigation
  /// return would then offer "send for review" again on a document already
  /// sent. This set makes a successful submission final for the life of the
  /// screen, independently of how the status stream behaves.
  final Set<String> _submittedDocumentIds = <String>{};

  DateTime? _validUntil;

  @override
  void initState() {
    super.initState();
    _sessionSub = _service.watchLatestSession(widget.businessId).listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _session = snapshot;
          final id = snapshot.documentId;
          if (id != null && id != _documentId) {
            _documentId = id;
            _documentStatus = null;
            _documentSub?.cancel();
            _documentSub = _service.watchDocumentStatus(id).listen(
              (status) {
                if (!mounted) return;
                setState(() => _documentStatus = status);
              },
              // A read that fails must never read as "nothing is
              // happening": leaving the status null keeps the
              // session-derived stage authoritative, which is
              // awaitingSubmission at worst, never idle.
              onError: (_) {},
            );
          }
        });
      },
      // A denied or unavailable read must never be reported as "no
      // upload in progress" — that would re-open blind re-upload. It
      // simply leaves the local stage authoritative.
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _documentSub?.cancel();
    super.dispose();
  }

  /// The stage actually shown.
  ///
  /// Precedence, and why: a local in-progress stage wins first, because only
  /// this widget knows it is mid-call. Otherwise the DOCUMENT's own status
  /// decides once a document exists — it is the only record that can
  /// distinguish `clean` from `pending_review`, and the session cannot. The
  /// session is consulted last. A session status of `consumed` therefore
  /// yields `awaitingSubmission`, never `awaitingReview`: the upload session
  /// being spent says nothing about whether anyone has been asked to review
  /// the resulting document.
  ComplianceEvidenceStage get _effectiveStage {
    if (_stage == ComplianceEvidenceStage.requestingSession ||
        _stage == ComplianceEvidenceStage.uploading) {
      return _stage;
    }
    if (_submittingForReview) return ComplianceEvidenceStage.awaitingSubmission;
    if (_documentStatus != null) {
      return stageForDocumentStatus(_documentStatus);
    }
    final fromSession = stageForSessionStatus(_session.status);
    if (fromSession != ComplianceEvidenceStage.idle) return fromSession;
    return _stage;
  }

  /// Positive allowlist. Any stage not explicitly enumerated as
  /// upload-enabled — including [ComplianceEvidenceStage.unknownState] and
  /// any stage a future change adds — disables every input.
  bool get _uploadControlsEnabled =>
      !_submitting &&
      !_submittingForReview &&
      complianceUploadEnabledStages.contains(_effectiveStage);

  bool get _submitForReviewEnabled =>
      !_submittingForReview &&
      !_submitting &&
      complianceSubmitEnabledStages.contains(_effectiveStage) &&
      _documentId != null &&
      !_submittedDocumentIds.contains(_documentId) &&
      _submissionRelationship != null &&
      _validUntil != null;

  /// The relationship this document is submitted under.
  ///
  /// Taken from the session's server-recorded `declaredSellerRelationship`
  /// first: that is the relationship the upload was actually authorized for,
  /// and it is the only one available after navigation or an app restart,
  /// when the local dropdown selection is gone and — correctly — disabled.
  /// The local selection is a fallback for the same-visit case only, and can
  /// never override what the server recorded.
  SellerRelationship? get _submissionRelationship =>
      _session.declaredSellerRelationship ?? _relationship;

  /// Whether ANY operation is in progress or the state is not one that
  /// explicitly permits acting. Deliberately expressed as "not enabled"
  /// rather than "in one of these bad states": a status the client does not
  /// recognise, an absent one, or a stage introduced later all land here.
  bool get _inFlight => !_uploadControlsEnabled;

  /// Genuinely mid-operation, as opposed to merely not-enabled. Drives only
  /// the "please wait" notice, never any control's enablement.
  bool get _processingInFlight {
    final stage = _effectiveStage;
    return _submitting ||
        _submittingForReview ||
        stage == ComplianceEvidenceStage.requestingSession ||
        stage == ComplianceEvidenceStage.uploading ||
        stage == ComplianceEvidenceStage.processing;
  }

  bool get _canSubmit =>
      _uploadControlsEnabled &&
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

  Future<void> _pickValidUntil() async {
    if (!complianceSubmitEnabledStages.contains(_effectiveStage)) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _validUntil = picked;
      _failure = null;
    });
  }

  /// Revision 30 §G's `clean -> pending_review` transition, performed by the
  /// existing `submitComplianceDocument` callable.
  ///
  /// Explicit, not automatic: the callable requires `validUntil`, a value
  /// only the seller knows, so no client could fire this on promotion without
  /// inventing a validity date.
  Future<void> _submitForReview() async {
    // Latch first, before any await. The session stream re-delivers on every
    // rebuild, reconnect and navigation return, so a guard that lived only in
    // the stream handler would fire again on each of those.
    if (_submittingForReview || !_submitForReviewEnabled) return;
    _submittingForReview = true;

    final documentId = _documentId!;
    final relationship = _submissionRelationship!;
    final validUntil = _validUntil!;
    setState(() => _failure = null);

    try {
      await _service.submitDocumentForReview(
        documentId: documentId,
        sellerRelationship: relationship,
        validUntil: validUntil,
      );
      // Record the success so no re-delivered `clean` snapshot can offer to
      // submit this same document again. Deliberately NOT setting an
      // awaitingReview stage locally: the document's own status is the
      // authority, and the stream delivers it. Claiming pending_review
      // before the record says so is exactly the defect this correction
      // closes, so the screen simply stops offering the action instead.
      _submittedDocumentIds.add(documentId);
    } on ComplianceEvidenceException catch (error) {
      if (!mounted) return;
      setState(() => _failure = error.kind);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failure = ComplianceEvidenceFailureKind.generic);
    } finally {
      _submittingForReview = false;
      if (mounted) setState(() {});
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
      case ComplianceEvidenceStage.awaitingSubmission:
        // Truthful for `clean`: the document exists and the seller still has
        // to send it. Never "waiting for review" — nobody has been asked yet.
        return _submittingForReview
            ? l10n.complianceEvidenceSubmittingForReview
            : l10n.complianceEvidenceStageAwaitingSubmission;
      case ComplianceEvidenceStage.awaitingReview:
        return l10n.complianceEvidenceStageAwaitingReview;
      case ComplianceEvidenceStage.reviewClosed:
        return l10n.complianceEvidenceStageReviewClosed;
      case ComplianceEvidenceStage.unknownState:
        return l10n.complianceEvidenceStageUnknown;
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

            // Only while work is genuinely in flight. `awaitingSubmission`
            // also disables the upload controls, but nothing is being
            // processed then — the seller is the one who must act, and
            // telling them to wait would be false.
            if (_processingInFlight) ...[
              const SizedBox(height: 12),
              Text(
                l10n.complianceEvidenceUploadInProgressNotice,
                key: const Key('complianceEvidenceInProgressNotice'),
              ),
            ],

            // Shown only while the promoted document is genuinely `clean`.
            if (complianceSubmitEnabledStages.contains(_effectiveStage) &&
                !_submittedDocumentIds.contains(_documentId)) ...[
              const SizedBox(height: 20),
              Text(
                l10n.complianceEvidenceValidUntilRequired,
                key: const Key('complianceEvidenceValidUntilHint'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('complianceEvidenceValidUntilButton'),
                onPressed: _submittingForReview ? null : _pickValidUntil,
                child: Text(
                  _validUntil == null
                      ? l10n.complianceEvidencePickValidUntil
                      : '${l10n.complianceEvidenceValidUntilLabel}: '
                            '${_validUntil!.toIso8601String().split('T').first}',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('complianceEvidenceSubmitForReviewButton'),
                onPressed: _submitForReviewEnabled ? _submitForReview : null,
                child: Text(l10n.complianceEvidenceSubmitForReview),
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
