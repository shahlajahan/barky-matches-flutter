class CheckoutCompletionGuard {
  bool _handled = false;

  bool get handled => _handled;

  String? claimPaidSellerOrder(Map<String, dynamic>? paymentState) {
    if (_handled ||
        paymentState?['paid'] != true ||
        paymentState?['cartReconciled'] != true) {
      return null;
    }

    final rawIds = paymentState?['sellerOrderIds'];
    if (rawIds is! Iterable) return null;

    for (final value in rawIds) {
      final sellerOrderId = value?.toString().trim() ?? '';
      if (sellerOrderId.isEmpty) continue;
      _handled = true;
      return sellerOrderId;
    }
    return null;
  }
}
