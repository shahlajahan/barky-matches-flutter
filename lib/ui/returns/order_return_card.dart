import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order_return.dart';
import '../../services/order_return_service.dart';
import '../../theme/app_theme.dart';

class OrderReturnCard extends StatefulWidget {
  final OrderReturnRecord record;
  final bool isSeller;
  final bool isBuyer;
  final VoidCallback? onChanged;

  const OrderReturnCard({
    super.key,
    required this.record,
    required this.isSeller,
    required this.isBuyer,
    this.onChanged,
  });

  @override
  State<OrderReturnCard> createState() => _OrderReturnCardState();
}

class _OrderReturnCardState extends State<OrderReturnCard> {
  bool _isProcessingReturn = false;
  bool _refundLoading = false;

  Color _statusColor(OrderReturnStatus status) {
    switch (status) {
      case OrderReturnStatus.pending:
        return Colors.orange;
      case OrderReturnStatus.approved:
        return Colors.blue;
      case OrderReturnStatus.rejected:
        return Colors.red;
      case OrderReturnStatus.shippedBack:
        return Colors.teal;
      case OrderReturnStatus.receivedBySeller:
        return Colors.deepPurple;
      case OrderReturnStatus.refundPending:
        return Colors.orange;
      case OrderReturnStatus.refundFailed:
        return Colors.redAccent;
      case OrderReturnStatus.refunded:
        return Colors.green;
      case OrderReturnStatus.cancelled:
        return Colors.grey;
    }
  }

  String _statusLabel(AppLocalizations l10n, OrderReturnStatus status) {
    switch (status) {
      case OrderReturnStatus.pending:
        return l10n.returnStatusPending;
      case OrderReturnStatus.approved:
        return l10n.returnStatusApproved;
      case OrderReturnStatus.rejected:
        return l10n.returnStatusRejected;
      case OrderReturnStatus.shippedBack:
        return l10n.returnStatusShippedBack;
      case OrderReturnStatus.receivedBySeller:
        return l10n.returnStatusReceivedBySeller;
      case OrderReturnStatus.refundPending:
        return l10n.returnStatusRefundPending;
      case OrderReturnStatus.refundFailed:
        return l10n.returnStatusRefundFailed;
      case OrderReturnStatus.refunded:
        return l10n.returnStatusRefunded;
      case OrderReturnStatus.cancelled:
        return l10n.returnStatusCancelled;
    }
  }

  String _reasonLabel(AppLocalizations l10n, OrderReturnReason reason) {
    switch (reason) {
      case OrderReturnReason.damaged:
        return l10n.returnReasonDamaged;
      case OrderReturnReason.wrongProduct:
        return l10n.returnReasonWrongProduct;
      case OrderReturnReason.missingParts:
        return l10n.returnReasonMissingParts;
      case OrderReturnReason.notAsDescribed:
        return l10n.returnReasonNotAsDescribed;
      case OrderReturnReason.changedMind:
        return l10n.returnReasonChangedMind;
      case OrderReturnReason.other:
        return l10n.returnReasonOther;
    }
  }

  String _refundTypeLabel(AppLocalizations l10n, RefundType type) {
    switch (type) {
      case RefundType.full:
        return l10n.refundTypeFullLabel;
      case RefundType.partial:
        return l10n.refundTypePartialLabel;
      case RefundType.shipping:
        return l10n.refundTypeShippingLabel;
    }
  }

  String _shippingResponsibilityLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'buyer':
        return l10n.shippingResponsibilityBuyerLabel;
      case 'seller':
        return l10n.shippingResponsibilitySellerLabel;
      case 'seller_if_contract_carrier':
      default:
        return l10n.shippingResponsibilityContractCarrierLabel;
    }
  }

  String _trackingUrl(String carrier, String code) {
    final c = carrier.toLowerCase().trim();
    if (c.contains('aras')) {
      return 'https://kargotakip.araskargo.com.tr/mainpage.aspx?code=$code';
    }
    if (c.contains('yurtici') || c.contains('yurtiçi')) {
      return 'https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=$code';
    }
    if (c.contains('mng')) {
      return 'https://www.mngkargo.com.tr/gonderi-takip?code=$code';
    }
    if (c.contains('ptt')) {
      return 'https://gonderitakip.ptt.gov.tr/Track/Verify?q=$code';
    }
    if (c.contains('hepsijet')) {
      return 'https://www.hepsijet.com/gonderi-takibi/$code';
    }
    if (c.contains('sendeo')) {
      return 'https://sendeo.com.tr/tracking/$code';
    }
    if (c.contains('ups')) {
      return 'https://www.ups.com/track?tracknum=$code';
    }
    if (c.contains('dhl')) {
      return 'https://www.dhl.com/tr-tr/home/tracking.html?tracking-id=$code';
    }
    return '';
  }

  Future<void> _showApproveDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final notesController = TextEditingController();
    String shippingResponsibility = widget.record.shippingResponsibility;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.approveReturnButton),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: shippingResponsibility,
                      decoration: InputDecoration(
                        labelText: l10n.shippingResponsibilityLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'seller_if_contract_carrier',
                          child: Text(
                            l10n.shippingResponsibilityContractCarrierLabel,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'seller',
                          child: Text(l10n.shippingResponsibilitySellerLabel),
                        ),
                        DropdownMenuItem(
                          value: 'buyer',
                          child: Text(l10n.shippingResponsibilityBuyerLabel),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => shippingResponsibility = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.notesOptional,
                        hintText: l10n.descriptionLabel,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.approveReturnButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await OrderReturnService.instance.approveReturn(
        returnId: widget.record.returnId,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        shippingResponsibility: shippingResponsibility,
      );

      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.rejectReturnButton),
          content: TextField(
            controller: notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.notesOptional,
              hintText: l10n.descriptionLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.rejectReturnButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await OrderReturnService.instance.rejectReturn(
        returnId: widget.record.returnId,
        notes: notesController.text.trim().isEmpty
            ? l10n.rejectReturnButton
            : notesController.text.trim(),
      );
      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.cancelReturnButton),
          content: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.notesOptional,
              hintText: l10n.descriptionLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.cancelReturnButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await OrderReturnService.instance.cancelReturn(
        returnId: widget.record.returnId,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  Future<void> _showShippedBackDialog(BuildContext context) async {
    if (_isProcessingReturn) return;
    final l10n = AppLocalizations.of(context)!;
    final trackingController = TextEditingController();
    final originalCarrier = await OrderReturnService.instance
        .resolveOriginalCarrierForReturn(
          sellerOrderId: widget.record.sellerOrderId,
          rootOrderId: widget.record.rootOrderId,
        );

    if (!context.mounted) return;

    if (originalCarrier == null || originalCarrier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.carrierMissingFromOrder)),
      );
      return;
    }

    final carrierController = TextEditingController(text: originalCarrier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.markShippedBackButton),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: carrierController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: l10n.returnCarrierLabel,
                  helperText: l10n.returnCarrierHelperText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trackingController,
                decoration: InputDecoration(
                  labelText: l10n.returnTrackingNumberLabel,
                  hintText: l10n.enterTrackingNumber,
                  helperText: l10n.returnTrackingNumberHelperText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.markShippedBackButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final trackingNumber = trackingController.text.trim();
    final carrier = carrierController.text.trim();

    if (trackingNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.trackingNumberRequired)),
        );
      }
      return;
    }

    if (carrier.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.returnCarrierIsRequired)),
        );
      }
      return;
    }

    try {
      setState(() => _isProcessingReturn = true);
      debugPrint('🚚 RETURN CARRIER => $carrier');
      debugPrint('🚚 RETURN TRACKING => $trackingNumber');
      await OrderReturnService.instance.markShippedBack(
        returnId: widget.record.returnId,
        trackingNumber: trackingNumber,
        carrier: carrier,
      );
      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.returnShippedBackFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingReturn = false);
      }
    }
  }

  Future<void> _showRefundDialog(BuildContext context) async {
    if (_refundLoading) return;
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController(
      text: widget.record.refundAmount.toStringAsFixed(2),
    );
    final notesController = TextEditingController();
    String refundType = widget.record.refundType.value;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.triggerRefundButton),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.refundAmountLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: refundType,
                      decoration: InputDecoration(
                        labelText: l10n.refundTypeLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text(l10n.refundTypeFullLabel),
                        ),
                        DropdownMenuItem(
                          value: 'partial',
                          child: Text(l10n.refundTypePartialLabel),
                        ),
                        DropdownMenuItem(
                          value: 'shipping',
                          child: Text(l10n.refundTypeShippingLabel),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => refundType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.notesOptional,
                        hintText: l10n.descriptionLabel,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.triggerRefundButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final paymentId = (widget.record.paymentId ??
            widget.record.refundDetails['paymentId'] ??
            '')
        .toString();
    final resolvedPaymentId = paymentId.isNotEmpty
        ? paymentId
        : await OrderReturnService.instance.resolvePaymentIdForReturn(
            returnId: widget.record.returnId,
          );
    if (!context.mounted) return;
    if (resolvedPaymentId == null || resolvedPaymentId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred('Missing paymentId'))),
        );
      }
      return;
    }

    try {
      setState(() => _refundLoading = true);
      await OrderReturnService.instance.triggerRefund(
        returnId: widget.record.returnId,
        refundAmount: double.tryParse(amountController.text.trim()) ?? 0,
        refundType: refundType,
        paymentId: resolvedPaymentId,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refundLoading = false);
      }
    }
  }

  Future<void> _markReceived(BuildContext context) async {
    if (_isProcessingReturn) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessingReturn = true);
    try {
      debugPrint('🧾 MARK RECEIVED CALL');
      debugPrint('🧾 returnId=${widget.record.returnId}');
      debugPrint('🧾 currentStatus=${widget.record.status.value}');
      debugPrint('🧾 sellerUid=${widget.record.sellerUid}');
      debugPrint('🧾 businessId=${widget.record.businessId}');
      await OrderReturnService.instance.markReceived(returnId: widget.record.returnId);
      widget.onChanged?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.returnActionCompleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingReturn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor(widget.record.status);
    final amountLabel = widget.record.refundAmount > 0
        ? '${widget.record.refundAmount.toStringAsFixed(2)} ₺'
        : '-';
    final shortId = widget.record.returnId.length > 6
        ? widget.record.returnId.substring(0, 6)
        : widget.record.returnId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.15)),
        boxShadow: AppTheme.cardShadow(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.returnRequestLabel(shortId),
                  style: AppTheme.h3(weight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(l10n, widget.record.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.reasonLabel}: ${_reasonLabel(l10n, widget.record.reason)}',
            style: AppTheme.body(color: AppTheme.textDark),
          ),
          if (widget.record.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.record.description,
              style: AppTheme.body(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('${l10n.returnAmountLabel}: $amountLabel'),
              _chip(
                '${l10n.shippingResponsibilityLabel}: '
                '${_shippingResponsibilityLabel(l10n, widget.record.shippingResponsibility)}',
              ),
              _chip(
                '${l10n.refundTypeLabel}: ${_refundTypeLabel(l10n, widget.record.refundType)}',
              ),
            ],
          ),
          if (widget.record.returnItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.itemsTitle,
              style: AppTheme.body(weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.record.returnItems
                  .map((item) => _chip('${item.name} x${item.quantity}'))
                  .toList(),
            ),
          ],
          if (widget.record.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final url = widget.record.images[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: widget.record.images.length,
              ),
            ),
          ],
          if (widget.record.trackingNumber != null ||
              widget.record.carrier != null ||
              (widget.record.refundDetails['originalTrackingNumber'] ?? '')
                  .toString()
                  .isNotEmpty ||
              (widget.record.refundDetails['originalCarrier'] ?? '')
                  .toString()
                  .isNotEmpty) ...[
            const SizedBox(height: 10),
            if ((widget.record.refundDetails['originalTrackingNumber'] ?? '').toString().isNotEmpty ||
                (widget.record.refundDetails['originalCarrier'] ?? '').toString().isNotEmpty) ...[
              Text(
                l10n.originalShipmentTrackingLabel,
                style: AppTheme.caption(
                  color: AppTheme.textDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${l10n.trackingNumberLabel}: ${(widget.record.refundDetails['originalTrackingNumber'] ?? '-').toString()}',
                style: AppTheme.caption(color: AppTheme.textDark),
              ),
              Text(
                l10n.carrierLabel(
                  (widget.record.refundDetails['originalCarrier'] ?? '-')
                      .toString(),
                ),
                style: AppTheme.caption(color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
            ],
            if ((widget.record.trackingNumber ?? '').isNotEmpty ||
                (widget.record.carrier ?? '').isNotEmpty) ...[
              Text(
                l10n.returnShipmentTrackingLabel,
                style: AppTheme.caption(
                  color: AppTheme.textDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${l10n.returnTrackingNumberLabel}: ${widget.record.trackingNumber ?? '-'}',
                style: AppTheme.caption(color: AppTheme.textDark),
              ),
              Text(
                '${l10n.returnCarrierLabel}: ${widget.record.carrier ?? '-'}',
                style: AppTheme.caption(color: AppTheme.textDark),
              ),
              if ((widget.record.trackingNumber ?? '').isNotEmpty &&
                  (widget.record.carrier ?? '').isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final url = _trackingUrl(
                      widget.record.carrier ?? '',
                      widget.record.trackingNumber ?? '',
                    );
                    if (url.isEmpty) return;
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(l10n.trackShipmentButton),
                ),
            ],
          ],
          if (widget.record.timeline.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.returnTimelineTitle,
              style: AppTheme.body(weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...widget.record.timeline.map((step) {
              final status = (step['status'] ?? '').toString();
              final at = (step['at'] ?? '').toString();
              final note = (step['note'] ?? '').toString();
              final localizedStatus = status == 'shipped_back'
                  ? l10n.returnShippedBackTimelineLabel
                  : _statusLabel(
                      l10n,
                      OrderReturnStatusX.fromString(status),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $localizedStatus ${at.isNotEmpty ? '• $at' : ''}${note.isNotEmpty ? ' • $note' : ''}',
                  style: AppTheme.caption(color: AppTheme.muted),
                ),
              );
            }),
          ],
          if (widget.record.refundDetails.isNotEmpty &&
              (widget.record.status == OrderReturnStatus.refunded ||
                  widget.record.status == OrderReturnStatus.refundFailed)) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.refundResultLabel}: ${widget.record.refundDetails['status'] ?? 'success'}',
              style: AppTheme.caption(
                color: widget.record.status == OrderReturnStatus.refunded
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.isBuyer &&
                  widget.record.status == OrderReturnStatus.pending)
                OutlinedButton(
                  onPressed: () => _showCancelDialog(context),
                  child: Text(l10n.cancelReturnButton),
                ),
              if (widget.isBuyer &&
                  widget.record.status == OrderReturnStatus.approved)
                ElevatedButton(
                  onPressed: _isProcessingReturn
                      ? null
                      : () => _showShippedBackDialog(context),
                  child: Text(l10n.markShippedBackButton),
                ),
              if (widget.isSeller &&
                  widget.record.status == OrderReturnStatus.pending)
                ElevatedButton(
                  onPressed: () => _showApproveDialog(context),
                  child: Text(l10n.approveReturnButton),
                ),
              if (widget.isSeller &&
                  widget.record.status == OrderReturnStatus.pending)
                OutlinedButton(
                  onPressed: () => _showRejectDialog(context),
                  child: Text(l10n.rejectReturnButton),
                ),
              if (widget.isSeller &&
                  (widget.record.status == OrderReturnStatus.approved ||
                      widget.record.status == OrderReturnStatus.shippedBack))
                ElevatedButton(
                  onPressed:
                      _isProcessingReturn ? null : () => _markReceived(context),
                  child: Text(l10n.markReceivedButton),
                ),
              if (widget.isSeller &&
                  (widget.record.status == OrderReturnStatus.receivedBySeller ||
                      widget.record.status == OrderReturnStatus.refundFailed))
                ElevatedButton(
                  onPressed: _refundLoading ? null : () => _showRefundDialog(context),
                  child: Text(l10n.triggerRefundButton),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTheme.caption(
          color: AppTheme.textDark,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
