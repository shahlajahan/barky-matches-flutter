import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order_return.dart';
import '../../services/order_return_service.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedProductIds.addAll(
      widget.items
          .map((e) => (e['productId'] ?? '').toString())
          .where((e) => e.isNotEmpty),
    );
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

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectReturnItemsLabel)));
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
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.refundAmountLabel}: ${_estimatedRefundAmount.toStringAsFixed(2)} ₺',
                  style: AppTheme.body(weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
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
