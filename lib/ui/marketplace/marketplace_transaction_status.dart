import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/ui/marketplace/marketplace_invoice_panel.dart';

class MarketplaceTransactionStatus extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool compact;
  final bool showInvoiceActions;
  final bool showUserInvoiceActions;
  final String? collectionName;
  final String? transactionId;

  const MarketplaceTransactionStatus({
    super.key,
    required this.data,
    this.compact = false,
    this.showInvoiceActions = false,
    this.showUserInvoiceActions = false,
    this.collectionName,
    this.transactionId,
  });

  @override
  State<MarketplaceTransactionStatus> createState() =>
      _MarketplaceTransactionStatusState();
}

class _MarketplaceTransactionStatusState
    extends State<MarketplaceTransactionStatus> {
  @override
  Widget build(BuildContext context) {
    final marketplace = _asMap(widget.data['marketplace']);
    final invoice = _asMap(widget.data['invoice']);
    final compliance = _asMap(widget.data['compliance']);
    final paymentStatus = (widget.data['paymentStatus'] ?? '').toString();
    final lifecycle =
        (marketplace['lifecycleStatus'] ?? widget.data['status'] ?? 'PENDING')
            .toString();
    final invoiceStatus = (invoice['status'] ?? 'pending_upload').toString();
    final delayed =
        marketplace['delayedAction'] == true ||
        compliance['delayedResponse'] == true;
    final warning = (marketplace['warningState'] ?? '').toString();
    final punishment = (marketplace['punishmentState'] ?? '').toString();
    final warningCount = (compliance['warningCount'] as num?)?.toInt() ?? 0;
    final penaltyPoints = (compliance['penaltyPoints'] as num?)?.toInt() ?? 0;

    final chips = <_StatusChipData>[
      _StatusChipData('Lifecycle: ${_label(lifecycle)}', Colors.blueGrey),
      if (paymentStatus.isNotEmpty)
        _StatusChipData('Payment: ${_label(paymentStatus)}', Colors.indigo),
      _StatusChipData(
        'Invoice: ${_label(invoiceStatus)}',
        _invoiceColor(invoiceStatus),
      ),
      if (delayed) _StatusChipData('Delayed', Colors.deepOrange),
      if (warning.isNotEmpty)
        _StatusChipData('Warning: ${_label(warning)}', Colors.orange),
      if (punishment.isNotEmpty)
        _StatusChipData('Punishment: ${_label(punishment)}', Colors.red),
      if (warningCount > 0)
        _StatusChipData('Warnings: $warningCount', Colors.orange),
      if (penaltyPoints > 0)
        _StatusChipData('Penalty: $penaltyPoints', Colors.red),
    ];

    return Padding(
      padding: EdgeInsets.only(top: widget.compact ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) => _chip(chip)).toList(),
          ),
          if (widget.showInvoiceActions &&
              widget.collectionName != null &&
              widget.transactionId != null) ...[
            MarketplaceInvoicePanel(
              data: widget.data,
              collectionName: widget.collectionName!,
              transactionId: widget.transactionId!,
              businessActions: true,
              compact: widget.compact,
            ),
          ] else if (widget.showUserInvoiceActions &&
              widget.collectionName != null &&
              widget.transactionId != null &&
              ((invoice['invoiceUrl'] ??
                      invoice['pdfUrl'] ??
                      widget.data['invoiceUrl'] ??
                      '')
                  .toString()
                  .isNotEmpty)) ...[
            MarketplaceInvoicePanel(
              data: widget.data,
              collectionName: widget.collectionName!,
              transactionId: widget.transactionId!,
              userActions: true,
              compact: widget.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(_StatusChipData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.color,
          fontWeight: FontWeight.w700,
          fontSize: widget.compact ? 10 : 11,
        ),
      ),
    );
  }

  static Color _invoiceColor(String status) {
    switch (status.toLowerCase()) {
      case 'uploaded_valid':
      case 'approved':
      case 'issued':
      case 'ready':
        return Colors.green;
      case 'uploaded_with_issues':
      case 'late':
        return Colors.deepOrange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  static String _label(String value) {
    final text = value.trim().replaceAll('_', ' ');
    if (text.isEmpty) return '-';
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}

class _StatusChipData {
  final String label;
  final Color color;

  const _StatusChipData(this.label, this.color);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
