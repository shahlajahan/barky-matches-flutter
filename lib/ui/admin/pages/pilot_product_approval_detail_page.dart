import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller, marketplaceFunctionsRegion;

MarketplaceFunctionCaller _defaultCallableInvoker() {
  final functions = FirebaseFunctions.instanceFor(
    region: marketplaceFunctionsRegion,
  );
  return (name, data) async {
    final result = await functions.httpsCallable(name).call(data);
    return result.data;
  };
}

// Mirrors `add_product_page.dart`'s own `sellerRelationshipValues` — that
// list is `@visibleForTesting` (production-code use outside its own file
// is an analyzer warning), so the closed 6-value set is duplicated here
// rather than imported.
const List<String> _kSellerRelationshipValues = [
  'brand_owner',
  'manufacturer',
  'authorized_distributor',
  'authorized_dealer',
  'importer',
  'reseller',
];

// Revision 28 pilot product approval contract — §10.1's closed 8-value
// `allowedPilotCategory` enum, kept byte-identical to
// `pilotProductApproval.js`'s `ALLOWED_PILOT_CATEGORIES`.
const List<String> _kAllowedPilotCategories = [
  'food',
  'treats',
  'litter',
  'toys',
  'collars_leads',
  'beds',
  'bowls',
  'grooming_tools',
];

// The two reason codes an admin's own revoke call may choose between —
// kept byte-identical to `pilotProductApproval.js`'s
// `ADMIN_REVOKE_REASON_CODES`.
const String _kReasonAdminManual = 'pilot_revoked_admin_manual';
const String _kReasonContentChanged = 'pilot_revoked_content_changed';

// Marketplace Revision 35 (Slice 7A) — the closed four-value pilot class
// set, kept byte-identical to `complianceConstants.js`'s
// `PILOT_PRODUCT_CLASS_VALUES`. This list only decides what the admin is
// OFFERED; the authoritative allowlist is the server's, which rejects
// anything outside it regardless of what this client sends.
const List<String> _kPilotProductClasses = [
  'sealed_dry_food',
  'sealed_wet_food',
  'non_medicinal_treats',
  'non_biocidal_litter',
];

class PilotProductApprovalDetailPage extends StatefulWidget {
  final String businessId;
  final String productId;

  /// Test-only seams — production call sites never supply these, always
  /// getting the real `FirebaseFirestore.instance` and a real
  /// `FirebaseFunctions.instanceFor(region: marketplaceFunctionsRegion)`
  /// callable invoker. Mirrors `AddProductPage.firestoreOverride` and
  /// `MarketplaceCatalogService`'s own `MarketplaceFunctionCaller` seam.
  @visibleForTesting
  final FirebaseFirestore? firestoreOverride;
  @visibleForTesting
  final MarketplaceFunctionCaller? callableInvoker;

  const PilotProductApprovalDetailPage({
    super.key,
    required this.businessId,
    required this.productId,
    @visibleForTesting this.firestoreOverride,
    @visibleForTesting this.callableInvoker,
  });

  @override
  State<PilotProductApprovalDetailPage> createState() =>
      _PilotProductApprovalDetailPageState();
}

class _PilotProductApprovalDetailPageState
    extends State<PilotProductApprovalDetailPage> {
  String? _selectedCategory;
  bool _attested = false;
  bool _isSubmitting = false;

  // Marketplace Revision 36 — server-authoritative approval readiness.
  //
  // The Approve button is driven ENTIRELY by what the server last said. The
  // client never computes an approval fingerprint and never reads
  // `productComplianceDecisions`; `_readinessFingerprint` only ever holds a
  // value this page received from `getPilotProductApprovalReadiness`.
  bool _readinessLoading = false;
  bool _readinessReady = false;
  String? _readinessReasonCode;
  String? _readinessFingerprint;
  int? _readinessValidUntilMillis;
  Object? _readinessError;
  // Monotonic request id: a response from a superseded load is discarded
  // rather than allowed to re-enable Approve against stale state.
  int _readinessSeq = 0;
  // Signature of the canonical product fields readiness depends on. When the
  // product stream reports a change to any of them the snapshot is stale by
  // construction, so readiness is reloaded without waiting for an approval to
  // fail. Evidence- and decision-side changes never touch the product
  // document, and are covered by the explicit re-check control, by the
  // stale-approval path, and by the server's own transactional revalidation.
  String? _readinessProductSignature;

  // Revision 35 (Slice 7A) classification form state. `_selectedClass` is
  // seeded from canonical server state on first build and thereafter follows
  // the admin's own selection, so a live update never silently discards an
  // in-progress edit.
  String? _selectedClass;
  bool _classSeeded = false;
  final TextEditingController _classificationReason = TextEditingController();
  bool _classificationReasonTouched = false;
  bool _isClassifying = false;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
  }

  @override
  void dispose() {
    _classificationReason.dispose();
    super.dispose();
  }

  /// Asks the server whether this product can be approved right now, and — if
  /// it can — for the exact fingerprint `approvePilotProduct` will expect.
  ///
  /// This is the ONLY source of an approval fingerprint in the client. It is
  /// a preview, not authority: the value it returns is an
  /// optimistic-concurrency token that the approval transaction revalidates.
  Future<void> _loadReadiness() async {
    final seq = ++_readinessSeq;
    setState(() {
      _readinessLoading = true;
      _readinessError = null;
      // Approve stays disabled for the whole in-flight window: a readiness
      // answer that is being refetched is not an answer.
      _readinessReady = false;
      _readinessFingerprint = null;
    });
    try {
      final result = await _invoke('getPilotProductApprovalReadiness', {
        'businessId': widget.businessId,
        'productId': widget.productId,
      });
      if (!mounted || seq != _readinessSeq) return;
      final map = result is Map ? result : const {};
      setState(() {
        _readinessLoading = false;
        _readinessReady = map['ready'] == true;
        _readinessReasonCode = map['reasonCode'] as String?;
        _readinessFingerprint = map['ready'] == true
            ? map['approvalFingerprint'] as String?
            : null;
        _readinessValidUntilMillis = map['decisionValidUntilMillis'] is int
            ? map['decisionValidUntilMillis'] as int
            : null;
      });
    } catch (e) {
      if (!mounted || seq != _readinessSeq) return;
      setState(() {
        _readinessLoading = false;
        _readinessReady = false;
        _readinessReasonCode = null;
        _readinessFingerprint = null;
        _readinessError = e;
      });
    }
  }

  /// The canonical product fields the readiness snapshot is computed over.
  /// Only used to detect that a reload is required — never to compute
  /// anything the server is authoritative for.
  String _productSignature(Map<String, dynamic> data) {
    return [
      data['name'],
      data['description'],
      data['price'],
      data['currency'],
      data['category'],
      data['brand'],
      data['barcode'],
      data['salePrice'],
      data['kdvRate'],
      data['sellerRelationship'],
      data['media'],
      data['pilotProductClass'],
      data['pilotProductClassificationRevision'],
      data['marketplaceBusinessGenerationId'],
      data['moderationStatus'],
      data['isActive'],
      data['productInputRevision'],
    ].map((v) => '$v').join('\u0000');
  }

  MarketplaceFunctionCaller get _invoke =>
      widget.callableInvoker ?? _defaultCallableInvoker();

  DocumentReference<Map<String, dynamic>> get _productRef =>
      (widget.firestoreOverride ?? FirebaseFirestore.instance)
          .collection('businesses')
          .doc(widget.businessId)
          .collection('products')
          .doc(widget.productId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pilotAdminDetailTitle),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _productRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorOccurred('${snapshot.error}')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return Center(child: Text(l10n.pilotAdminErrorNotFound));
          }
          final data = snapshot.data!.data()!;
          return _buildContent(context, l10n, data);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> data,
  ) {
    // A canonical change to any readiness-bound field invalidates the
    // snapshot immediately, so Approve can never sit enabled against a
    // product that has moved on. Scheduled off the build frame because it
    // calls setState. Evidence- and decision-side changes never touch the
    // product document; those are covered by the explicit re-check control,
    // by the stale-approval path, and by the server's own transactional
    // revalidation inside `approvePilotProduct`.
    final signature = _productSignature(data);
    if (_readinessProductSignature == null) {
      _readinessProductSignature = signature;
    } else if (_readinessProductSignature != signature && !_readinessLoading) {
      _readinessProductSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadReadiness();
      });
    }

    final approval = data['pilotProductApproval'];
    final isActive = approval is Map && approval['active'] == true;
    final wasRevoked = approval is Map && approval['revokedAt'] != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMedia(data),
        const SizedBox(height: 16),
        Text(
          (data['name'] as String?) ?? widget.productId,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        _StatusChip(isActive: isActive, wasRevoked: wasRevoked, l10n: l10n),
        const SizedBox(height: 16),
        if ((data['description'] as String?)?.isNotEmpty == true) ...[
          Text(l10n.description, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(data['description'] as String),
          const SizedBox(height: 16),
        ],
        _buildFieldRow(
          l10n.priceValue('${data['price'] ?? '-'} ${data['currency'] ?? ''}'),
        ),
        if (data['salePrice'] != null)
          _buildFieldRow(l10n.salePriceLabel('${data['salePrice']}')),
        _buildFieldRow(l10n.categoryValue('${data['category'] ?? '-'}')),
        if ((data['brand'] as String?)?.isNotEmpty == true)
          _buildFieldRow('${l10n.brandLabel}: ${data['brand']}'),
        if ((data['barcode'] as String?)?.isNotEmpty == true)
          _buildFieldRow(l10n.barcodeLabel('${data['barcode']}')),
        if (_kSellerRelationshipValues.contains(data['sellerRelationship']))
          _buildFieldRow(
            '${l10n.sellerRelationshipLabel}: '
            '${_sellerRelationshipLabel(l10n, data['sellerRelationship'] as String)}',
          ),
        const SizedBox(height: 24),
        // Classification comes BEFORE the approval controls, because it is a
        // precondition of approval rather than a step within it.
        _buildClassificationSection(context, l10n, data, isActive: isActive),
        const SizedBox(height: 24),
        if (isActive)
          _buildRevokeSection(context, l10n)
        else
          _buildApproveSection(context, l10n, data),
      ],
    );
  }

  /// Revision 35 (Slice 7A) — the admin-only classification control.
  ///
  /// Displays canonical server state only: the class shown is the one stored
  /// on the product, and "not classified" is shown whenever no recognised
  /// value is stored — an unrecognised legacy value is never rendered as if
  /// it were a valid class.
  Widget _buildClassificationSection(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> data, {
    required bool isActive,
  }) {
    final stored = data['pilotProductClass'];
    final currentClass = _kPilotProductClasses.contains(stored)
        ? stored as String
        : null;
    if (!_classSeeded) {
      _selectedClass = currentClass;
      _classSeeded = true;
    }

    final reasonText = _classificationReason.text.trim();
    final reasonMissing = reasonText.isEmpty;
    final busy = _isClassifying || _isSubmitting;
    final canSave = !busy && _selectedClass != null && !reasonMissing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pilotAdminClassificationSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.pilotAdminClassificationExplanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.pilotAdminClassificationCurrentLabel}: '
              '${currentClass == null ? l10n.pilotAdminClassificationNotClassified : _pilotClassLabel(l10n, currentClass)}',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('pilotClassificationDropdown'),
              initialValue: _selectedClass,
              decoration: InputDecoration(
                labelText: l10n.pilotAdminClassificationFieldLabel,
              ),
              items: _kPilotProductClasses
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_pilotClassLabel(l10n, value)),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => setState(() => _selectedClass = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pilotClassificationReasonField'),
              controller: _classificationReason,
              enabled: !busy,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.pilotAdminClassificationReasonLabel,
                hintText: l10n.pilotAdminClassificationReasonHint,
                errorText: (_classificationReasonTouched && reasonMissing)
                    ? l10n.pilotAdminClassificationReasonRequired
                    : null,
              ),
              onChanged: (_) => setState(() {
                _classificationReasonTouched = true;
              }),
            ),
            // Shown only while the product is genuinely published, so the
            // warning always describes what this action will actually do.
            if (isActive) ...[
              const SizedBox(height: 4),
              Text(
                l10n.pilotAdminClassificationUnpublishWarning,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange.shade900),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('pilotClassificationSaveButton'),
                onPressed: canSave
                    ? () => _handleClassify(
                        context,
                        l10n,
                        isActive: isActive,
                        currentClass: currentClass,
                      )
                    : null,
                child: _isClassifying
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.pilotAdminClassificationSaveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pilotClassLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'sealed_dry_food':
        return l10n.pilotAdminClassSealedDryFood;
      case 'sealed_wet_food':
        return l10n.pilotAdminClassSealedWetFood;
      case 'non_medicinal_treats':
        return l10n.pilotAdminClassNonMedicinalTreats;
      case 'non_biocidal_litter':
        return l10n.pilotAdminClassNonBiocidalLitter;
      default:
        return value;
    }
  }

  Widget _buildMedia(Map<String, dynamic> data) {
    final media = data['media'];
    if (media is! List || media.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = media[index];
          if (item is! Map) return const SizedBox.shrink();
          final url =
              (item['thumbnailUrl'] as String?) ??
              (item['originalUrl'] as String?);
          if (url == null) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text),
    );
  }

  String _sellerRelationshipLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'brand_owner':
        return l10n.sellerRelationshipBrandOwner;
      case 'manufacturer':
        return l10n.sellerRelationshipManufacturer;
      case 'authorized_distributor':
        return l10n.sellerRelationshipAuthorizedDistributor;
      case 'authorized_dealer':
        return l10n.sellerRelationshipAuthorizedDealer;
      case 'importer':
        return l10n.sellerRelationshipImporter;
      case 'reseller':
        return l10n.sellerRelationshipReseller;
      default:
        return value;
    }
  }

  String _pilotCategoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'food':
        return l10n.pilotAdminCategoryFood;
      case 'treats':
        return l10n.pilotAdminCategoryTreats;
      case 'litter':
        return l10n.pilotAdminCategoryLitter;
      case 'toys':
        return l10n.pilotAdminCategoryToys;
      case 'collars_leads':
        return l10n.pilotAdminCategoryCollarsLeads;
      case 'beds':
        return l10n.pilotAdminCategoryBeds;
      case 'bowls':
        return l10n.pilotAdminCategoryBowls;
      case 'grooming_tools':
        return l10n.pilotAdminCategoryGroomingTools;
      default:
        return value;
    }
  }

  Widget _buildApproveSection(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> data,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pilotAdminOperationalClassificationNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Keyed since Revision 35 (Slice 7A) put a second dropdown —
              // the classification control — on this same page.
              key: const Key('pilotApprovalCategoryDropdown'),
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n.pilotAdminCategoryLabel,
              ),
              items: _kAllowedPilotCategories
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_pilotCategoryLabel(l10n, value)),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedCategory = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _attested,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _attested = value ?? false),
              title: Text(l10n.pilotAdminAttestationLabel),
            ),
            const SizedBox(height: 8),
            _buildReadinessPanel(context, l10n),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('pilotApproveButton'),
                // Approve is enabled only while the SERVER's most recent
                // answer is `ready` and a fingerprint from that same answer is
                // in hand. Loading, blocked and errored readiness all keep it
                // disabled.
                onPressed:
                    (_isSubmitting ||
                        _readinessLoading ||
                        !_readinessReady ||
                        _readinessFingerprint == null ||
                        _selectedCategory == null ||
                        !_attested)
                    ? null
                    : () => _handleApprove(context, l10n),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.pilotAdminApproveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the server's own readiness verdict — loading, ready, or blocked
  /// with a stable localized reason. Nothing here is derived locally; the
  /// screen never claims a product is approvable on its own initiative.
  Widget _buildReadinessPanel(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (_readinessLoading) {
      return Row(
        key: const Key('pilotReadinessLoading'),
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.pilotAdminReadinessLoading,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    final Widget body;
    if (_readinessError != null) {
      body = Text(
        _readinessErrorMessage(l10n, _readinessError!),
        key: const Key('pilotReadinessBlocked'),
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade900),
      );
    } else if (_readinessReady) {
      final validUntil = _readinessValidUntilMillis;
      body = Column(
        key: const Key('pilotReadinessReady'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pilotAdminReadinessReady,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green.shade900,
            ),
          ),
          if (validUntil != null)
            Text(
              l10n.pilotAdminReadinessDecisionValidUntil(
                DateTime.fromMillisecondsSinceEpoch(
                  validUntil,
                ).toLocal().toString().split('.').first,
              ),
              style: theme.textTheme.bodySmall,
            ),
        ],
      );
    } else {
      body = Column(
        key: const Key('pilotReadinessBlocked'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pilotAdminReadinessBlockedTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.orange.shade900,
            ),
          ),
          Text(
            _readinessReasonMessage(l10n, _readinessReasonCode),
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('pilotReadinessRefreshButton'),
            onPressed: (_isSubmitting || _readinessLoading)
                ? null
                : _loadReadiness,
            child: Text(l10n.pilotAdminReadinessRefresh),
          ),
        ),
      ],
    );
  }

  /// Maps the server's stable readiness reason codes onto localized copy.
  /// An unrecognised code degrades to the generic message rather than being
  /// shown raw.
  String _readinessReasonMessage(AppLocalizations l10n, String? reasonCode) {
    switch (reasonCode) {
      case 'readiness-class-missing':
        return l10n.pilotAdminErrorClassMissing;
      case 'readiness-class-unsupported':
        return l10n.pilotAdminErrorClassUnsupported;
      case 'readiness-decision-missing':
        return l10n.pilotAdminReadinessDecisionMissing;
      case 'readiness-decision-not-eligible':
        return l10n.pilotAdminReadinessDecisionNotEligible;
      case 'readiness-decision-expired':
        return l10n.pilotAdminReadinessDecisionExpired;
      case 'readiness-decision-product-mismatch':
        return l10n.pilotAdminReadinessDecisionMismatch;
      case 'readiness-evidence-stale':
        return l10n.pilotAdminReadinessEvidenceStale;
      case 'readiness-policy-mismatch':
        return l10n.pilotAdminReadinessPolicyMismatch;
      case 'readiness-generation-mismatch':
      case 'readiness-generation-not-initialized':
        return l10n.pilotAdminErrorStaleGeneration;
      case 'readiness-product-not-found':
      case 'readiness-business-not-found':
      case 'readiness-product-business-mismatch':
        return l10n.pilotAdminErrorNotFound;
      case 'readiness-seller-not-active':
        return l10n.pilotAdminErrorSellerNotActive;
      case 'readiness-invalid-transition':
        return l10n.pilotAdminReadinessInvalidTransition;
      case 'readiness-already-approved':
        return l10n.pilotAdminReadinessAlreadyApproved;
      case 'readiness-limit-exceeded':
        return l10n.pilotAdminErrorLimitExceeded;
      case 'readiness-malformed-state':
        return l10n.pilotAdminReadinessMalformedState;
      default:
        return l10n.pilotAdminErrorGeneric;
    }
  }

  String _readinessErrorMessage(AppLocalizations l10n, Object error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      final reasonCode = details is Map ? details['reasonCode'] : null;
      if (reasonCode is String) {
        return _readinessReasonMessage(l10n, reasonCode);
      }
    }
    return l10n.pilotAdminErrorGeneric;
  }

  Widget _buildRevokeSection(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => _handleRevoke(context, l10n),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.pilotAdminRevokeButton),
      ),
    );
  }

  /// Approves the product using the exact fingerprint the server returned
  /// from `getPilotProductApprovalReadiness`.
  ///
  /// Nothing is computed here. The fingerprint is an optimistic-concurrency
  /// token: `approvePilotProduct` re-reads and recomputes the whole
  /// authoritative state inside its own transaction and rejects a stale one,
  /// so a `stale-content` failure is an expected outcome, not an error to
  /// paper over. When it happens the screen reloads readiness and stops —
  /// it never re-submits on the admin's behalf.
  Future<void> _handleApprove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Captured before the first await: after it, this State's `context` is
    // no longer safe to read even though `mounted` may still be true.
    final messenger = ScaffoldMessenger.of(context);

    final fingerprint = _readinessFingerprint;
    // A readiness answer that is missing, blocked or superseded never reaches
    // the server. `_isSubmitting` is checked here and latched immediately
    // below, BEFORE the confirmation dialog rather than after it: taps
    // delivered in the same frame all run this method before any rebuild
    // disables the button, so the latch — not the button's own disabled
    // state — is what makes a second one a no-op.
    if (!_readinessReady || fingerprint == null || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pilotAdminApproveConfirmTitle),
        content: Text(l10n.pilotAdminApproveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.pilotAdminApproveButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // The in-flight flag is what disables the Approve button for the whole
    // round trip, so a second tap has nothing to hit. That button-level guard
    // is the load-bearing one; the `_isSubmitting` clause in the early return
    // above is its belt-and-braces companion.
    setState(() => _isSubmitting = true);
    try {
      await _invoke('approvePilotProduct', {
        'businessId': widget.businessId,
        'productId': widget.productId,
        'allowedPilotCategory': _selectedCategory,
        'reviewedContentFingerprint': fingerprint,
        'attestNoProhibitedClaim': true,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.pilotAdminApproveSucceeded)),
      );
      // Re-read authoritative state. The product stream refreshes the
      // document itself; this refreshes the server's verdict about it.
      await _loadReadiness();
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final reasonCode = details is Map ? details['reasonCode'] : null;
      if (reasonCode == 'stale-content') {
        // The authoritative state moved between readiness and approval.
        // Reload the snapshot and require a fresh, explicit admin tap — never
        // an automatic retry with a newly-fetched fingerprint, which would
        // approve state the admin never saw.
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.pilotAdminReadinessStale)),
        );
        await _loadReadiness();
      } else {
        _showError(messenger, l10n, e);
      }
    } catch (e) {
      _showError(messenger, l10n, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Sends exactly one `setPilotProductClassification` call per confirmed
  /// action. The button is disabled for the whole round trip, so a double tap
  /// cannot produce a second invocation, and the resulting state is read back
  /// from the product stream rather than assumed here.
  Future<void> _handleClassify(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isActive,
    required String? currentClass,
  }) async {
    // Captured before the first await, for the same reason as in
    // `_handleApprove`.
    final messenger = ScaffoldMessenger.of(context);

    final selected = _selectedClass;
    final reason = _classificationReason.text.trim();
    if (selected == null || reason.isEmpty) return;

    // Confirm only when this action really will unpublish something.
    if (isActive && selected != currentClass) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.pilotAdminClassificationConfirmTitle),
          content: Text(l10n.pilotAdminClassificationConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.pilotAdminClassificationSaveButton),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isClassifying = true);
    try {
      final result = await _invoke('setPilotProductClassification', {
        'businessId': widget.businessId,
        'productId': widget.productId,
        'pilotProductClass': selected,
        'reason': reason,
      });
      if (!mounted) return;
      // The server's own report of what happened — never a local guess.
      final map = result is Map ? result : const {};
      final String message;
      if (map['changed'] != true) {
        message = l10n.pilotAdminClassificationUnchanged;
      } else if (map['unpublished'] == true) {
        message = l10n.pilotAdminClassificationUnpublished;
      } else {
        message = l10n.pilotAdminClassificationSaved;
      }
      setState(() {
        _classificationReason.clear();
        _classificationReasonTouched = false;
      });
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      // A classification change moves a readiness-bound input, so the
      // server's previous verdict — and any fingerprint in it — is void.
      await _loadReadiness();
    } catch (e) {
      _showError(messenger, l10n, e);
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  Future<void> _handleRevoke(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Captured before the first await, for the same reason as above.
    final messenger = ScaffoldMessenger.of(context);
    final reasonCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RevokeReasonDialog(l10n: l10n),
    );
    if (reasonCode == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await _invoke('revokePilotProductApproval', {
        'businessId': widget.businessId,
        'productId': widget.productId,
        'reasonCode': reasonCode,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.pilotAdminRevokeButton)),
      );
      // Revocation returns the product to an unapproved state; the previous
      // readiness verdict no longer describes it.
      await _loadReadiness();
    } catch (e) {
      _showError(messenger, l10n, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Takes an already-captured [ScaffoldMessengerState] rather than a
  /// [BuildContext]: every caller reaches this after an `await`, where the
  /// State's own `context` is no longer safe to read even while `mounted` is
  /// still true. Capturing the messenger before the first await is what makes
  /// the whole error path context-safe.
  void _showError(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    Object e,
  ) {
    if (!mounted) return;
    String message = l10n.pilotAdminErrorGeneric;
    if (e is FirebaseFunctionsException) {
      final details = e.details;
      final reasonCode = details is Map ? details['reasonCode'] : null;
      switch (reasonCode) {
        case 'limit-exceeded':
          message = l10n.pilotAdminErrorLimitExceeded;
          break;
        case 'stale-content':
          message = l10n.pilotAdminErrorStaleContent;
          break;
        case 'stale-generation':
        case 'generation-not-initialized':
          message = l10n.pilotAdminErrorStaleGeneration;
          break;
        case 'seller-not-active':
          message = l10n.pilotAdminErrorSellerNotActive;
          break;
        // Revision 35 (Slice 7A) — approval's own classification
        // precondition, and the classification callable's stable codes.
        case 'pilot-class-missing-or-invalid':
          message = l10n.pilotAdminErrorClassMissing;
          break;
        case 'classification-unsupported-class':
          message = l10n.pilotAdminErrorClassUnsupported;
          break;
        case 'classification-invalid-transition':
          message = l10n.pilotAdminErrorClassNotClassifiable;
          break;
        case 'classification-stale-generation':
        case 'classification-generation-not-initialized':
          message = l10n.pilotAdminErrorStaleGeneration;
          break;
        case 'classification-product-not-found':
        case 'classification-business-not-found':
          message = l10n.pilotAdminErrorNotFound;
          break;
        default:
          message = e.message ?? l10n.pilotAdminErrorGeneric;
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RevokeReasonDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _RevokeReasonDialog({required this.l10n});

  @override
  State<_RevokeReasonDialog> createState() => _RevokeReasonDialogState();
}

class _RevokeReasonDialogState extends State<_RevokeReasonDialog> {
  String _reasonCode = _kReasonAdminManual;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.pilotAdminRevokeConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.pilotAdminRevokeConfirmMessage),
          const SizedBox(height: 12),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: _kReasonAdminManual,
            groupValue: _reasonCode,
            onChanged: (value) => setState(() => _reasonCode = value!),
            title: Text(l10n.pilotAdminRevokeReasonManual),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: _kReasonContentChanged,
            groupValue: _reasonCode,
            onChanged: (value) => setState(() => _reasonCode = value!),
            title: Text(l10n.pilotAdminRevokeReasonContentChanged),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _reasonCode),
          child: Text(l10n.pilotAdminRevokeButton),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final bool wasRevoked;
  final AppLocalizations l10n;

  const _StatusChip({
    required this.isActive,
    required this.wasRevoked,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (isActive) {
      label = l10n.pilotStatusApproved;
      color = Colors.green;
    } else if (wasRevoked) {
      label = l10n.pilotStatusRevoked;
      color = Colors.orange;
    } else {
      label = l10n.pilotStatusPendingReview;
      color = Colors.grey;
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
    );
  }
}
