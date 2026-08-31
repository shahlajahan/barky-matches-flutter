import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/marketplace_catalog_service.dart'
    show MarketplaceFunctionCaller, marketplaceFunctionsRegion;
import '../pilot_product_fingerprint.dart';

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
        if (isActive)
          _buildRevokeSection(context, l10n)
        else
          _buildApproveSection(context, l10n, data),
      ],
    );
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
              initialValue: _selectedCategory,
              decoration: InputDecoration(labelText: l10n.pilotAdminCategoryLabel),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _selectedCategory == null || !_attested)
                    ? null
                    : () => _handleApprove(context, l10n, data),
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

  Future<void> _handleApprove(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> data,
  ) async {
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

    setState(() => _isSubmitting = true);
    try {
      final fingerprint = computePilotProductContentFingerprint(data);
      await _invoke('approvePilotProduct', {
        'businessId': widget.businessId,
        'productId': widget.productId,
        'allowedPilotCategory': _selectedCategory,
        'reviewedContentFingerprint': fingerprint,
        'attestNoProhibitedClaim': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pilotAdminApproveButton)));
    } catch (e) {
      _showError(context, l10n, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleRevoke(BuildContext context, AppLocalizations l10n) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pilotAdminRevokeButton)));
    } catch (e) {
      _showError(context, l10n, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(BuildContext context, AppLocalizations l10n, Object e) {
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
        default:
          message = e.message ?? l10n.pilotAdminErrorGeneric;
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
