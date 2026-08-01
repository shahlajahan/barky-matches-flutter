enum BuyerOrderSort {
  newest,
  oldest,
  productAscending,
  productDescending,
  sellerAscending,
  sellerDescending,
  amountDescending,
  amountAscending,
}

enum BuyerOrderStatusFilter {
  all,
  pending,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
  failed,
  refundedOrReturned,
}

class BuyerOrderSourceRecord {
  const BuyerOrderSourceRecord({
    required this.id,
    required this.data,
    required this.isSellerOrder,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool isSellerOrder;
}

class BuyerOrderListItem {
  const BuyerOrderListItem({
    required this.sellerOrderId,
    required this.canOpenDetail,
    required this.rootOrderId,
    required this.orderNumber,
    required this.sellerName,
    required this.primaryProductName,
    required this.additionalItemCount,
    required this.productImageUrl,
    required this.createdAt,
    required this.total,
    required this.currency,
    required this.status,
    required this.carrier,
    required this.trackingNumber,
  });

  final String sellerOrderId;
  final bool canOpenDetail;
  final String? rootOrderId;
  final String? orderNumber;
  final String? sellerName;
  final String? primaryProductName;
  final int additionalItemCount;
  final String? productImageUrl;
  final DateTime? createdAt;
  final double total;
  final String currency;
  final String status;
  final String? carrier;
  final String? trackingNumber;

  factory BuyerOrderListItem.fromRecord(BuyerOrderSourceRecord record) {
    final data = record.data;
    final items = _mapList(data['items']);
    final firstItem = items.isEmpty ? const <String, dynamic>{} : items.first;
    final sellerSnapshot = _map(data['sellerSnapshot']);
    final pricing = _map(data['pricing']);
    final shipping = _map(data['shipping']);
    final payment = _map(data['payment']);
    final sellerOrderIds = _stringList(data['sellerOrderIds']);
    final detailId = record.isSellerOrder
        ? record.id
        : sellerOrderIds.firstOrNull ?? '';

    return BuyerOrderListItem(
      sellerOrderId: detailId,
      canOpenDetail: detailId.isNotEmpty,
      rootOrderId: _firstString([
        data['rootOrderId'],
        record.isSellerOrder ? null : record.id,
      ]),
      orderNumber: _firstString([
        data['sellerOrderNumber'],
        data['orderNumber'],
        data['rootOrderNumber'],
      ]),
      sellerName: _firstString([
        sellerSnapshot['businessName'],
        sellerSnapshot['displayName'],
        sellerSnapshot['sellerBusinessName'],
        sellerSnapshot['shopName'],
        data['businessName'],
        data['displayName'],
        data['sellerBusinessName'],
        data['shopName'],
        firstItem['businessName'],
        firstItem['sellerBusinessName'],
        firstItem['shopName'],
      ]),
      primaryProductName: _firstString([
        firstItem['name'],
        firstItem['productName'],
        firstItem['title'],
      ]),
      additionalItemCount: items.length > 1 ? items.length - 1 : 0,
      productImageUrl: _firstString([
        firstItem['imageUrl'],
        firstItem['thumbnailUrl'],
        firstItem['image'],
        firstItem['photoUrl'],
      ]),
      createdAt: _firstDate([
        data['createdAt'],
        data['paidAt'],
        payment['paidAt'],
        data['updatedAt'],
      ]),
      total: _firstDouble([
        pricing['grandTotal'],
        data['grandTotal'],
        data['total'],
        data['amount'],
      ]),
      currency:
          _firstString([
            pricing['currency'],
            data['currency'],
            payment['currency'],
          ]) ??
          'TRY',
      status: normalizeBuyerOrderStatus(
        _firstString([
              data['status'],
              data['paymentStatus'],
              payment['status'],
            ]) ??
            'pending',
      ),
      carrier: _firstString([
        shipping['carrier'],
        shipping['carrierCode'],
        data['carrier'],
        firstItem['carrier'],
        firstItem['selectedCarrier'],
        firstItem['shippingMethod'],
      ]),
      trackingNumber: _firstString([
        shipping['trackingNumber'],
        shipping['trackingCode'],
        data['trackingNumber'],
        data['trackingCode'],
      ]),
    );
  }
}

List<BuyerOrderListItem> mergeBuyerOrderRecords({
  required Iterable<BuyerOrderSourceRecord> sellerOrders,
  required Iterable<BuyerOrderSourceRecord> legacyRootOrders,
}) {
  final sellerById = <String, BuyerOrderSourceRecord>{};
  for (final record in sellerOrders) {
    sellerById[record.id] = record;
  }

  final representedRootIds = <String>{};
  for (final record in sellerById.values) {
    final rootOrderId = _firstString([record.data['rootOrderId']]);
    if (rootOrderId != null) representedRootIds.add(rootOrderId);
  }

  final merged = <BuyerOrderListItem>[
    for (final record in sellerById.values)
      BuyerOrderListItem.fromRecord(record),
    for (final record in legacyRootOrders)
      if (!representedRootIds.contains(record.id))
        BuyerOrderListItem.fromRecord(record),
  ];

  final unique = <String, BuyerOrderListItem>{};
  for (final item in merged) {
    final key = item.sellerOrderId.isNotEmpty
        ? 'seller:${item.sellerOrderId}'
        : 'root:${item.rootOrderId ?? item.orderNumber ?? unique.length}';
    unique.putIfAbsent(key, () => item);
  }
  return unique.values.toList(growable: false);
}

List<BuyerOrderListItem> presentBuyerOrders(
  Iterable<BuyerOrderListItem> orders, {
  required BuyerOrderSort sort,
  required BuyerOrderStatusFilter statusFilter,
}) {
  final indexed = orders.indexed
      .where(
        (entry) =>
            statusFilter == BuyerOrderStatusFilter.all ||
            buyerOrderMatchesFilter(entry.$2.status, statusFilter),
      )
      .toList();

  indexed.sort((left, right) {
    final comparison = _compareOrders(left.$2, right.$2, sort);
    return comparison != 0 ? comparison : left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

bool buyerOrderMatchesFilter(String status, BuyerOrderStatusFilter filter) {
  final normalized = normalizeBuyerOrderStatus(status);
  return switch (filter) {
    BuyerOrderStatusFilter.all => true,
    BuyerOrderStatusFilter.pending => normalized == 'pending',
    BuyerOrderStatusFilter.paid => normalized == 'paid',
    BuyerOrderStatusFilter.processing =>
      normalized == 'processing' || normalized == 'preparing',
    BuyerOrderStatusFilter.shipped => normalized == 'shipped',
    BuyerOrderStatusFilter.delivered => normalized == 'delivered',
    BuyerOrderStatusFilter.cancelled => normalized == 'cancelled',
    BuyerOrderStatusFilter.failed => normalized == 'failed',
    BuyerOrderStatusFilter.refundedOrReturned =>
      normalized == 'refunded' || normalized == 'returned',
  };
}

String normalizeBuyerOrderStatus(Object? value) {
  final status = value?.toString().trim().toLowerCase() ?? '';
  if (status.contains('fail')) return 'failed';
  if (status.contains('cancel')) return 'cancelled';
  if (status.contains('refund')) return 'refunded';
  if (status.contains('return')) return 'returned';
  if (status.contains('deliver')) return 'delivered';
  if (status.contains('ship')) return 'shipped';
  if (status.contains('prepar')) return 'preparing';
  if (status.contains('process') || status.contains('confirm')) {
    return 'processing';
  }
  if (status.contains('paid')) return 'paid';
  if (status.contains('pending') || status.isEmpty) return 'pending';
  return status;
}

int _compareOrders(
  BuyerOrderListItem left,
  BuyerOrderListItem right,
  BuyerOrderSort sort,
) {
  return switch (sort) {
    BuyerOrderSort.newest => _compareDates(
      left.createdAt,
      right.createdAt,
      descending: true,
    ),
    BuyerOrderSort.oldest => _compareDates(
      left.createdAt,
      right.createdAt,
      descending: false,
    ),
    BuyerOrderSort.productAscending => _compareText(
      left.primaryProductName,
      right.primaryProductName,
    ),
    BuyerOrderSort.productDescending => _compareText(
      right.primaryProductName,
      left.primaryProductName,
    ),
    BuyerOrderSort.sellerAscending => _compareText(
      left.sellerName,
      right.sellerName,
    ),
    BuyerOrderSort.sellerDescending => _compareText(
      right.sellerName,
      left.sellerName,
    ),
    BuyerOrderSort.amountDescending => right.total.compareTo(left.total),
    BuyerOrderSort.amountAscending => left.total.compareTo(right.total),
  };
}

int _compareText(String? left, String? right) =>
    (left ?? '').toLowerCase().compareTo((right ?? '').toLowerCase());

int _compareDates(DateTime? left, DateTime? right, {required bool descending}) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return descending ? right.compareTo(left) : left.compareTo(right);
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is Iterable
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];

List<String> _stringList(Object? value) => value is Iterable
    ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

String? _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) return normalized;
  }
  return null;
}

double _firstDouble(Iterable<Object?> values) {
  for (final value in values) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

DateTime? _firstDate(Iterable<Object?> values) {
  for (final value in values) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue?.toDate();
      if (result is DateTime) return result;
    } catch (_) {
      // Try the next compatible legacy timestamp.
    }
  }
  return null;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
