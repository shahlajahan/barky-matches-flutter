import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/compliance_review_service.dart';

/// Marketplace Revision 30 §J Slice 4 — the admin evidence review surface.
///
/// Boundary, stated once and enforced throughout: approving here approves the
/// compliance DOCUMENT. It creates no scope, no evidence link, no product
/// decision, no classification, no eligibility, no activation and no
/// publication — Revision 30 §J slices 5-7 — and this screen offers no control
/// that could. Every write goes through `reviewComplianceDocument`; nothing
/// here writes Firestore directly.

/// Opens an external viewer for a short-lived evidence URL. Injectable so
/// tests never invoke a platform handler.
typedef ComplianceEvidenceOpener = Future<bool> Function(String url);

Future<bool> _defaultOpener(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class ComplianceEvidenceReviewListPage extends StatelessWidget {
  const ComplianceEvidenceReviewListPage({
    super.key,
    this.service,
    this.opener,
    this.pageSize = 25,
  });

  final ComplianceReviewService? service;
  final ComplianceEvidenceOpener? opener;
  final int pageSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reviewService = service ?? ComplianceReviewService();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminComplianceReviewTitle)),
      body: StreamBuilder<List<ComplianceReviewItem>>(
        stream: reviewService.watchPendingReview(limit: pageSize),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              key: const Key('complianceReviewQueueError'),
              child: Text(l10n.somethingWentWrong),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              key: const Key('complianceReviewQueueEmpty'),
              child: Text(l10n.adminComplianceReviewEmpty),
            );
          }
          return ListView.builder(
            key: const Key('complianceReviewQueue'),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                key: Key('complianceReviewQueueItem_${item.documentId}'),
                title: Text(
                  item.documentType ?? l10n.adminComplianceReviewTitle,
                ),
                subtitle: Text(
                  '${l10n.adminComplianceReviewBusiness}: ${item.businessId}',
                ),
                // A row whose status this client cannot interpret is shown as
                // a blocked diagnostic entry and is never openable.
                enabled: item.isDecidable,
                onTap: item.isDecidable
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ComplianceEvidenceReviewDetailPage(
                            documentId: item.documentId,
                            service: reviewService,
                            opener: opener,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class ComplianceEvidenceReviewDetailPage extends StatefulWidget {
  const ComplianceEvidenceReviewDetailPage({
    super.key,
    required this.documentId,
    this.service,
    this.opener,
    this.now,
  });

  final String documentId;
  final ComplianceReviewService? service;
  final ComplianceEvidenceOpener? opener;
  final DateTime Function()? now;

  @override
  State<ComplianceEvidenceReviewDetailPage> createState() =>
      _ComplianceEvidenceReviewDetailPageState();
}

class _ComplianceEvidenceReviewDetailPageState
    extends State<ComplianceEvidenceReviewDetailPage> {
  late final ComplianceReviewService _service =
      widget.service ?? ComplianceReviewService();
  late final ComplianceEvidenceOpener _opener = widget.opener ?? _defaultOpener;
  DateTime _now() => (widget.now ?? DateTime.now)();

  final TextEditingController _reasonController = TextEditingController();

  /// Held in memory for this screen only. Never persisted, logged, routed,
  /// copied to the clipboard or sent to analytics, and dropped in dispose().
  ComplianceEvidenceGrant? _grant;
  bool _loadingEvidence = false;
  bool _viewed = false;

  bool _deciding = false;

  /// Set once a decision has been accepted by the server for this document.
  ///
  /// The in-call latch releases as soon as the call returns, while the
  /// document stream may still deliver `pending_review` for a moment — so a
  /// re-delivered snapshot, a rebuild or a navigation return would otherwise
  /// re-offer a decision that has already been taken. The server would refuse
  /// or replay it, but the reviewer should never be invited to try.
  bool _decisionRecorded = false;
  ComplianceReviewFailureKind? _failure;
  bool _staleNotice = false;

  @override
  void dispose() {
    // The short-lived bearer capability leaves memory with the screen.
    _grant = null;
    _reasonController.dispose();
    super.dispose();
  }

  bool get _evidenceUsable {
    final grant = _grant;
    return grant != null && grant.isSupported && !grant.isExpiredAt(_now());
  }

  /// Approval requires that the reviewer actually obtained AND opened the
  /// document. An expired or failed retrieval revokes that, so approval is
  /// disabled again until the evidence is fetched afresh.
  bool _canDecide(ComplianceReviewItem? doc) =>
      !_deciding &&
      !_decisionRecorded &&
      doc != null &&
      doc.isDecidable &&
      _evidenceUsable &&
      _viewed;

  Future<void> _loadEvidence() async {
    if (_loadingEvidence) return;
    setState(() {
      _loadingEvidence = true;
      _failure = null;
    });
    try {
      final grant = await _service.requestEvidence(widget.documentId);
      if (!mounted) return;
      setState(() {
        _grant = grant;
        // An inline-renderable image is presented immediately; a PDF is not
        // considered viewed until the reviewer actually opens it.
        _viewed = grant.canRenderInline;
      });
    } on ComplianceReviewException catch (error) {
      if (!mounted) return;
      setState(() {
        _grant = null;
        _viewed = false;
        _failure = error.kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _grant = null;
        _viewed = false;
        _failure = ComplianceReviewFailureKind.generic;
      });
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _openExternally() async {
    final grant = _grant;
    if (grant == null || !_evidenceUsable) return;
    final opened = await _opener(grant.downloadUrl);
    if (!mounted) return;
    setState(() {
      if (opened) {
        _viewed = true;
      } else {
        _failure = ComplianceReviewFailureKind.evidenceUnavailable;
      }
    });
  }

  Future<void> _decide({
    required bool approve,
    ComplianceReviewItem? doc,
  }) async {
    // Latch before any await. This is UX protection only: the server's
    // transaction and transition guard are the authority on whether a second
    // decision can take effect.
    if (_deciding || !_canDecide(doc)) return;
    final reason = _reasonController.text;
    if (!approve && reason.trim().isEmpty) {
      setState(() => _failure = ComplianceReviewFailureKind.invalidInput);
      return;
    }
    setState(() {
      _deciding = true;
      _failure = null;
      _staleNotice = false;
    });
    try {
      if (approve) {
        await _service.approve(widget.documentId);
      } else {
        await _service.reject(
          documentId: widget.documentId,
          rejectionReason: reason,
        );
      }
      // The decision is recorded as TAKEN so it cannot be repeated, but the
      // OUTCOME is deliberately not displayed locally: the document stream is
      // the authority and will deliver the final status. Showing approved or
      // rejected before the record says so would be an optimistic claim.
      _decisionRecorded = true;
    } on ComplianceReviewException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.kind;
        _staleNotice =
            error.kind == ComplianceReviewFailureKind.staleDecision ||
            error.kind == ComplianceReviewFailureKind.conflict;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failure = ComplianceReviewFailureKind.generic);
    } finally {
      _deciding = false;
      if (mounted) setState(() {});
    }
  }

  String _statusLabel(AppLocalizations l10n, ComplianceReviewItem doc) {
    switch (doc.status) {
      case ComplianceDocumentStatus.clean:
        return l10n.adminComplianceReviewStatusClean;
      case ComplianceDocumentStatus.pendingReview:
        return l10n.adminComplianceReviewStatusPendingReview;
      case ComplianceDocumentStatus.approved:
        return l10n.adminComplianceReviewStatusApproved;
      case ComplianceDocumentStatus.rejected:
        return l10n.adminComplianceReviewStatusRejected;
      case ComplianceDocumentStatus.revoked:
        return l10n.adminComplianceReviewStatusRevoked;
      case ComplianceDocumentStatus.expired:
        return l10n.adminComplianceReviewStatusExpired;
      case ComplianceDocumentStatus.superseded:
        return l10n.adminComplianceReviewStatusSuperseded;
      case null:
        return l10n.adminComplianceReviewUnknownState;
    }
  }

  String? _failureMessage(AppLocalizations l10n) {
    switch (_failure) {
      case null:
        return null;
      case ComplianceReviewFailureKind.unauthenticated:
      case ComplianceReviewFailureKind.notAdmin:
        return l10n.accessDenied;
      case ComplianceReviewFailureKind.notFound:
      case ComplianceReviewFailureKind.evidenceUnavailable:
        return l10n.adminComplianceReviewEvidenceFailed;
      case ComplianceReviewFailureKind.staleDecision:
      case ComplianceReviewFailureKind.conflict:
        return l10n.adminComplianceReviewStale;
      case ComplianceReviewFailureKind.invalidInput:
        return l10n.adminComplianceReviewRejectionReasonRequired;
      case ComplianceReviewFailureKind.unavailableRetry:
        return l10n.networkErrorTryAgain;
      case ComplianceReviewFailureKind.generic:
        return l10n.somethingWentWrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminComplianceReviewTitle)),
      body: StreamBuilder<ComplianceReviewItem?>(
        stream: _service.watchDocument(widget.documentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data;
          if (doc == null) {
            return Center(
              child: Text(l10n.adminComplianceReviewEvidenceFailed),
            );
          }
          final grant = _grant;
          final failureMessage = _failureMessage(l10n);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                key: const Key('complianceReviewScopeNotice'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.adminComplianceReviewNotApprovalScope),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _statusLabel(l10n, doc),
                key: const Key('complianceReviewStatusText'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              _field(l10n.adminComplianceReviewBusiness, doc.businessId),
              _field(l10n.adminComplianceReviewDocumentType, doc.documentType),
              _field(
                l10n.adminComplianceReviewRelationship,
                doc.sellerRelationship,
              ),
              _field(
                l10n.adminComplianceReviewValidUntil,
                doc.validUntil?.toIso8601String().split('T').first,
              ),
              _field(
                l10n.adminComplianceReviewUploadedAt,
                doc.uploadedAt?.toIso8601String().split('T').first,
              ),
              // Provenance the reviewer can check the file against. No path,
              // no bucket, no nonce, no scanner internals.
              _field(l10n.adminComplianceReviewProvenance, doc.contentHash),
              _field(
                l10n.adminComplianceReviewScanState,
                l10n.adminComplianceReviewScanState,
              ),

              const SizedBox(height: 20),
              if (_loadingEvidence)
                Text(
                  l10n.adminComplianceReviewEvidenceLoading,
                  key: const Key('complianceReviewEvidenceLoading'),
                )
              else
                OutlinedButton(
                  key: const Key('complianceReviewLoadEvidenceButton'),
                  onPressed: doc.isDecidable ? _loadEvidence : null,
                  child: Text(l10n.adminComplianceReviewLoadEvidence),
                ),

              if (grant != null && !grant.isSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.adminComplianceReviewEvidenceUnsupported,
                    key: const Key('complianceReviewUnsupported'),
                  ),
                ),

              if (grant != null && grant.isExpiredAt(_now()))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.adminComplianceReviewEvidenceExpired,
                    key: const Key('complianceReviewEvidenceExpired'),
                  ),
                ),

              if (grant != null && _evidenceUsable && grant.canRenderInline)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.network(
                    grant.downloadUrl,
                    key: const Key('complianceReviewInlineImage'),
                    errorBuilder: (context, error, stack) =>
                        Text(l10n.adminComplianceReviewEvidenceFailed),
                  ),
                ),

              if (grant != null && _evidenceUsable && !grant.canRenderInline)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  // PDF: no vetted in-app viewer exists and Slice 4's
                  // authorization forbids adding an arbitrary webview, so the
                  // authorized fallback hands the short-lived URL straight to
                  // the platform's external handler. It is never stored.
                  child: FilledButton.tonal(
                    key: const Key('complianceReviewOpenExternallyButton'),
                    onPressed: _openExternally,
                    child: Text(l10n.adminComplianceReviewOpenDocument),
                  ),
                ),

              if (!_viewed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.adminComplianceReviewMustViewFirst,
                    key: const Key('complianceReviewMustViewNotice'),
                  ),
                ),

              const SizedBox(height: 20),
              TextField(
                key: const Key('complianceReviewRejectionReasonField'),
                controller: _reasonController,
                enabled: _canDecide(doc),
                maxLength: 2000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.adminComplianceReviewRejectionReasonLabel,
                ),
              ),

              if (_deciding)
                Text(
                  l10n.adminComplianceReviewDeciding,
                  key: const Key('complianceReviewDecidingText'),
                ),

              const SizedBox(height: 8),
              FilledButton(
                key: const Key('complianceReviewApproveButton'),
                onPressed: _canDecide(doc)
                    ? () => _decide(approve: true, doc: doc)
                    : null,
                child: Text(l10n.adminComplianceReviewApprove),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('complianceReviewRejectButton'),
                onPressed: _canDecide(doc)
                    ? () => _decide(approve: false, doc: doc)
                    : null,
                child: Text(l10n.adminComplianceReviewReject),
              ),

              if (_staleNotice)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.adminComplianceReviewStale,
                    key: const Key('complianceReviewStaleNotice'),
                  ),
                ),

              if (failureMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    failureMessage,
                    key: const Key('complianceReviewFailureText'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $value'),
    );
  }
}
