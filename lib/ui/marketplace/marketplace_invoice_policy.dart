import 'package:flutter/material.dart';

class MarketplaceInvoicePolicy {
  static const completionBlockedMessage = 'Invoice required before completion';

  static String invoiceStatus(Map<String, dynamic> data) {
    final invoice = _asMap(data['invoice']);
    final documents = _asMap(data['documents']);
    return (invoice['status'] ??
            documents['invoiceStatus'] ??
            data['invoiceStatus'] ??
            'pending_upload')
        .toString()
        .trim()
        .toLowerCase();
  }

  static String paymentStatus(Map<String, dynamic> data) {
    return (data['paymentStatus'] ?? '').toString().trim().toLowerCase();
  }

  static bool canComplete(Map<String, dynamic> data) {
    final payment = paymentStatus(data);
    final invoice = invoiceStatus(data);
    final invoiceData = _asMap(data['invoice']);
    final invoiceUrl =
        (invoiceData['invoiceUrl'] ??
                invoiceData['pdfUrl'] ??
                data['invoiceUrl'] ??
                '')
            .toString()
            .trim();
    final allowed =
        payment == 'paid' &&
        (invoice == 'issued' || invoice == 'approved') &&
        invoiceUrl.isNotEmpty;

    debugPrint(
      'MARKETPLACE COMPLETE CHECK paymentStatus=$payment '
      'invoiceStatus=$invoice invoiceUrl=$invoiceUrl allowed=$allowed',
    );
    debugPrint(
      'MARKETPLACE INVOICE VALIDATION paymentStatus=$payment '
      'invoiceStatus=$invoice invoiceUrl=$invoiceUrl allowed=$allowed',
    );

    return allowed;
  }

  static bool guardCompletion(
    BuildContext context,
    Map<String, dynamic> data, {
    required String targetStatus,
  }) {
    if (targetStatus != 'completed') return true;
    if (canComplete(data)) return true;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(completionBlockedMessage)));
    return false;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
