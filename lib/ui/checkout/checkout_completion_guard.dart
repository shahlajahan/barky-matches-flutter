class CheckoutCompletionGuard {
  bool _handled = false;

  bool get handled => _handled;

  List<String> claimPaidSellerOrders(Map<String, dynamic>? paymentState) {
    if (_handled ||
        paymentState?['paid'] != true ||
        paymentState?['cartReconciled'] != true) {
      return const [];
    }

    final rawIds = paymentState?['sellerOrderIds'];
    final values = <Object?>[
      if (rawIds is Iterable) ...rawIds,
      paymentState?['sellerOrderId'],
    ];
    final sellerOrderIds = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final sellerOrderId = value?.toString().trim() ?? '';
      if (sellerOrderId.isEmpty || !seen.add(sellerOrderId)) continue;
      sellerOrderIds.add(sellerOrderId);
    }

    if (sellerOrderIds.isEmpty) return const [];
    _handled = true;
    return List.unmodifiable(sellerOrderIds);
  }

  /// Backwards-compatible single-order API.
  String? claimPaidSellerOrder(Map<String, dynamic>? paymentState) {
    final sellerOrderIds = claimPaidSellerOrders(paymentState);
    return sellerOrderIds.isEmpty ? null : sellerOrderIds.first;
  }
}
