import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order_return.dart';
import '../../services/order_return_service.dart';
import '../../theme/app_theme.dart';
import '../returns/return_shipping_summary_card.dart';

class ReturnRequestSheet extends StatefulWidget {
  final String sellerOrderId;
  final String rootOrderId;
  final String buyerUid;
  final String sellerUid;
  final String businessId;
  final List<Map<String, dynamic>> items;

  const ReturnRequestSheet({
    super.key,
    required this.sellerOrderId,
    required this.rootOrderId,
    required this.buyerUid,
    required this.sellerUid,
    required this.businessId,
    required this.items,
  });

  @override
  State<ReturnRequestSheet> createState() => _ReturnRequestSheetState();
}

class _ReturnRequestSheetState extends State<ReturnRequestSheet> {
  final _descriptionController = TextEditingController();
  final Set<String> _selectedProductIds = {};
  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  final List<String> _imageContentTypes = [];

  String _reason = OrderReturnReason.damaged.value;
  ReturnShippingPolicyPreview? _returnShippingPolicy;
  bool _returnShippingPolicyLoading = true;
  bool _returnShippingAcknowledged = false;
  int _returnShippingPolicyRequest = 0;

  @override
  void initState() {
    super.initState();
    _selectedProductIds.addAll(
      widget.items
          .map((e) => (e['productId'] ?? '').toString())
          .where((e) => e.isNotEmpty),
    );
    _loadReturnShippingPolicy();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _selectedItems {
    return widget.items
        .where((item) {
          final productId = (item['productId'] ?? '').toString();
          return _selectedProductIds.contains(productId);
        })
        .map((item) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice =
              (item['unitPrice'] as num?)?.toDouble() ??
              (item['price'] as num?)?.toDouble() ??
              0;
          return {
            'productId': (item['productId'] ?? '').toString(),
            'name': (item['name'] ?? '').toString(),
            'quantity': quantity,
            'unitPrice': unitPrice,
            'lineTotal':
                (item['lineTotal'] as num?)?.toDouble() ??
                (unitPrice * quantity),
            'imageUrl': item['imageUrl'],
          };
        })
        .toList();
  }

  double get _estimatedRefundAmount {
    return _selectedItems.fold<double>(
      0,
      (sum, item) => sum + ((item['lineTotal'] as num?)?.toDouble() ?? 0),
    );
  }

  ReturnShippingDisplayType _displayType(ReturnShippingPolicyPreview policy) {
    return switch (policy.kind) {
      ReturnShippingPolicyKind.buyer => ReturnShippingDisplayType.buyer,
      ReturnShippingPolicyKind.seller => ReturnShippingDisplayType.seller,
      ReturnShippingPolicyKind.contractedCarrier =>
        ReturnShippingDisplayType.contractedCarrier,
    };
  }

  Future<void> _loadReturnShippingPolicy() async {
    final requestId = ++_returnShippingPolicyRequest;
    if (mounted) {
      setState(() {
        _returnShippingPolicyLoading = true;
        _returnShippingAcknowledged = false;
      });
    }

    try {
      final policy = await OrderReturnService.instance
          .loadReturnShippingPolicyPreview(
            businessId: widget.businessId,
            productIds: _selectedProductIds,
          );
      if (!mounted || requestId != _returnShippingPolicyRequest) return;
      setState(() {
        _returnShippingPolicy = policy;
        _returnShippingPolicyLoading = false;
      });
    } catch (error) {
      debugPrint('Return shipping policy lookup failed: $error');
      if (!mounted || requestId != _returnShippingPolicyRequest) return;
      setState(() {
        // Fail safely: when policy cannot be loaded, warn that the buyer may
        // be responsible instead of presenting an unverified seller benefit.
        _returnShippingPolicy = const ReturnShippingPolicyPreview(
          kind: ReturnShippingPolicyKind.buyer,
        );
        _returnShippingPolicyLoading = false;
      });
    }
  }

  String _reasonLabel(AppLocalizations l10n, String reason) {
    switch (reason) {
      case 'damaged':
        return l10n.returnReasonDamaged;
      case 'wrong_product':
        return l10n.returnReasonWrongProduct;
      case 'missing_parts':
        return l10n.returnReasonMissingParts;
      case 'not_as_described':
        return l10n.returnReasonNotAsDescribed;
      case 'changed_mind':
        return l10n.returnReasonChangedMind;
      default:
        return l10n.returnReasonOther;
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );

    if (result == null) return;

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;

      _imageBytes.add(bytes);
      _imageNames.add(file.name);
      _imageContentTypes.add('image/jpeg');
    }

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.returnImagesAdded)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final policy = _returnShippingPolicy;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectReturnItemsLabel)));
      return;
    }
    if (_returnShippingPolicyLoading || policy == null) {
      return;
    }
    if (policy.buyerWarningRequired && !_returnShippingAcknowledged) {
      return;
    }

    final selectedReason = _reason.trim().isEmpty
        ? OrderReturnReason.other.value
        : _reason;
    final description = _descriptionController.text.trim();
    final fallbackDescription =
        '${_reasonLabel(l10n, selectedReason)} return request';
    final safeDescription = description.isEmpty
        ? fallbackDescription
        : description;

    debugPrint('🧾 return description raw="$description"');
    debugPrint('🧾 return description used="$safeDescription"');

    try {
      await OrderReturnService.instance.createReturnRequest(
        sellerOrderId: widget.sellerOrderId,
        rootOrderId: widget.rootOrderId,
        buyerUid: widget.buyerUid,
        sellerUid: widget.sellerUid,
        businessId: widget.businessId,
        reason: selectedReason,
        description: safeDescription,
        returnItems: _selectedItems,
        imageBytes: List.unmodifiable(_imageBytes),
        imageNames: List.unmodifiable(_imageNames),
        imageContentTypes: List.unmodifiable(_imageContentTypes),
        refundType: _selectedItems.length == widget.items.length
            ? RefundType.full.value
            : RefundType.partial.value,
        shippingResponsibility: '',
        refundAmount: _estimatedRefundAmount,
        returnWindowDays: 14,
        buyerAcknowledgedReturnShipping: _returnShippingAcknowledged,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ return create failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.requestReturnButton, style: AppTheme.h2()),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: InputDecoration(
                  labelText: l10n.selectReturnReasonLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: OrderReturnReason.damaged.value,
                    child: Text(l10n.returnReasonDamaged),
                  ),
                  DropdownMenuItem(
                    value: OrderReturnReason.wrongProduct.value,
                    child: Text(l10n.returnReasonWrongProduct),
                  ),
                  DropdownMenuItem(
                    value: OrderReturnReason.missingParts.value,
                    child: Text(l10n.returnReasonMissingParts),
                  ),
                  DropdownMenuItem(
                    value: OrderReturnReason.notAsDescribed.value,
                    child: Text(l10n.returnReasonNotAsDescribed),
                  ),
                  DropdownMenuItem(
                    value: OrderReturnReason.changedMind.value,
                    child: Text(l10n.returnReasonChangedMind),
                  ),
                  DropdownMenuItem(
                    value: OrderReturnReason.other.value,
                    child: Text(l10n.returnReasonOther),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.descriptionLabel,
                  hintText: l10n.returnDescriptionHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.selectReturnItemsLabel, style: AppTheme.h3()),
              const SizedBox(height: 8),
              ...widget.items.map((item) {
                final productId = (item['productId'] ?? '').toString();
                final selected = _selectedProductIds.contains(productId);
                final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                final title = (item['name'] ?? '').toString();
                final subtotal =
                    (item['lineTotal'] as num?)?.toDouble() ??
                    ((item['unitPrice'] as num?)?.toDouble() ?? 0) * quantity;

                return Card(
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedProductIds.add(productId);
                        } else {
                          _selectedProductIds.remove(productId);
                        }
                      });
                      _loadReturnShippingPolicy();
                    },
                    title: Text(title),
                    subtitle: Text(
                      '${l10n.qtyLabel(quantity.toString())} • ${subtotal.toStringAsFixed(2)} ₺',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(l10n.uploadImagesLabel, style: AppTheme.h3()),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.pickFromGallery),
              ),
              if (_imageNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _imageNames
                      .map((name) => Chip(label: Text(name)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.refundAmountLabel}: ${_estimatedRefundAmount.toStringAsFixed(2)} ₺',
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              if (_returnShippingPolicyLoading)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.returnShippingPolicyLoading)),
                      ],
                    ),
                  ),
                )
              else if (_returnShippingPolicy != null)
                ReturnShippingSummaryCard(
                  type: _displayType(_returnShippingPolicy!),
                  carrierCode: _returnShippingPolicy!.carrierCode,
                ),
              if (!_returnShippingPolicyLoading &&
                  (_returnShippingPolicy?.buyerWarningRequired ?? false)) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _returnShippingAcknowledged,
                  onChanged: (value) {
                    setState(
                      () => _returnShippingAcknowledged = value ?? false,
                    );
                  },
                  title: Text(l10n.returnShippingAcknowledgement),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      !_returnShippingPolicyLoading &&
                          _selectedItems.isNotEmpty &&
                          OrderReturnService.canSubmitWithReturnShippingPolicy(
                            policy: _returnShippingPolicy,
                            acknowledged: _returnShippingAcknowledged,
                          )
                      ? _submit
                      : null,
                  child: Text(l10n.requestReturnButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
