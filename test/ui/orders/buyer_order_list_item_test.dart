import 'package:barky_matches_fixed/ui/orders/buyer_order_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buyer order normalization and merging', () {
    test('multi-seller payment produces two visible buyer entries', () {
      final orders = mergeBuyerOrderRecords(
        sellerOrders: [
          _sellerRecord('seller-a', rootOrderId: 'root-1'),
          _sellerRecord('seller-b', rootOrderId: 'root-1'),
        ],
        legacyRootOrders: [
          _rootRecord('root-1', sellerOrderIds: ['seller-a', 'seller-b']),
        ],
      );

      expect(orders.map((order) => order.sellerOrderId), [
        'seller-a',
        'seller-b',
      ]);
    });

    test('paid seller orders are not excluded', () {
      final orders = presentBuyerOrders(
        [
          BuyerOrderListItem.fromRecord(
            _sellerRecord('paid-order', status: 'paid'),
          ),
        ],
        sort: BuyerOrderSort.newest,
        statusFilter: BuyerOrderStatusFilter.paid,
      );

      expect(orders.single.sellerOrderId, 'paid-order');
    });

    test(
      'legacy root order remains visible when no seller order represents it',
      () {
        final orders = mergeBuyerOrderRecords(
          sellerOrders: const [],
          legacyRootOrders: [
            _rootRecord('legacy-root', sellerOrderIds: ['legacy-seller']),
          ],
        );

        expect(orders, hasLength(1));
        expect(orders.single.sellerOrderId, 'legacy-seller');
        expect(orders.single.primaryProductName, 'Legacy product');
      },
    );

    test('duplicate refresh records remain unique', () {
      final duplicate = _sellerRecord('seller-a', rootOrderId: 'root-1');
      final orders = mergeBuyerOrderRecords(
        sellerOrders: [duplicate, duplicate],
        legacyRootOrders: const [],
      );

      expect(orders, hasLength(1));
    });

    test('missing optional fields normalize without throwing', () {
      final item = BuyerOrderListItem.fromRecord(
        const BuyerOrderSourceRecord(
          id: 'sparse',
          isSellerOrder: true,
          data: {},
        ),
      );

      expect(item.sellerOrderId, 'sparse');
      expect(item.total, 0);
      expect(item.currency, 'TRY');
      expect(item.status, 'pending');
      expect(item.primaryProductName, isNull);
    });
  });

  group('sorting and filtering', () {
    final oldest = _item(
      id: 'oldest',
      product: 'Alpha',
      seller: 'Zulu',
      amount: 10,
      date: DateTime(2025),
      status: 'paid',
    );
    final newest = _item(
      id: 'newest',
      product: 'Zulu',
      seller: 'Alpha',
      amount: 30,
      date: DateTime(2026),
      status: 'shipped',
    );
    final middle = _item(
      id: 'middle',
      product: 'Beta',
      seller: 'Beta',
      amount: 20,
      date: DateTime(2025, 6),
      status: 'returned',
    );
    late List<BuyerOrderListItem> orders;

    setUp(() => orders = [middle, oldest, newest]);

    test('date newest and oldest sorting', () {
      expect(_ids(orders, BuyerOrderSort.newest), [
        'newest',
        'middle',
        'oldest',
      ]);
      expect(_ids(orders, BuyerOrderSort.oldest), [
        'oldest',
        'middle',
        'newest',
      ]);
    });

    test('product A-Z and Z-A sorting', () {
      expect(_ids(orders, BuyerOrderSort.productAscending), [
        'oldest',
        'middle',
        'newest',
      ]);
      expect(_ids(orders, BuyerOrderSort.productDescending), [
        'newest',
        'middle',
        'oldest',
      ]);
    });

    test('seller A-Z and Z-A sorting', () {
      expect(_ids(orders, BuyerOrderSort.sellerAscending), [
        'newest',
        'middle',
        'oldest',
      ]);
      expect(_ids(orders, BuyerOrderSort.sellerDescending), [
        'oldest',
        'middle',
        'newest',
      ]);
    });

    test('amount high and low sorting', () {
      expect(_ids(orders, BuyerOrderSort.amountDescending), [
        'newest',
        'middle',
        'oldest',
      ]);
      expect(_ids(orders, BuyerOrderSort.amountAscending), [
        'oldest',
        'middle',
        'newest',
      ]);
    });

    test('status filtering combines with sorting', () {
      final returned = presentBuyerOrders(
        orders,
        sort: BuyerOrderSort.amountDescending,
        statusFilter: BuyerOrderStatusFilter.refundedOrReturned,
      );
      final shipped = presentBuyerOrders(
        orders,
        sort: BuyerOrderSort.oldest,
        statusFilter: BuyerOrderStatusFilter.shipped,
      );

      expect(returned.map((order) => order.sellerOrderId), ['middle']);
      expect(shipped.map((order) => order.sellerOrderId), ['newest']);
    });
  });
}

BuyerOrderSourceRecord _sellerRecord(
  String id, {
  String rootOrderId = 'root',
  String status = 'paid',
}) {
  return BuyerOrderSourceRecord(
    id: id,
    isSellerOrder: true,
    data: {
      'rootOrderId': rootOrderId,
      'sellerOrderNumber': 'SO-$id',
      'status': status,
      'createdAt': DateTime(2026),
      'sellerSnapshot': {'businessName': 'Seller $id'},
      'pricing': {'grandTotal': 15, 'currency': 'TRY'},
      'items': [
        {'name': 'Product $id', 'imageUrl': 'https://example.com/$id.png'},
      ],
    },
  );
}

BuyerOrderSourceRecord _rootRecord(
  String id, {
  required List<String> sellerOrderIds,
}) {
  return BuyerOrderSourceRecord(
    id: id,
    isSellerOrder: false,
    data: {
      'sellerOrderIds': sellerOrderIds,
      'orderNumber': 'ROOT-1',
      'createdAt': DateTime(2024),
      'items': [
        {'name': 'Legacy product'},
      ],
    },
  );
}

BuyerOrderListItem _item({
  required String id,
  required String product,
  required String seller,
  required double amount,
  required DateTime date,
  required String status,
}) {
  return BuyerOrderListItem(
    sellerOrderId: id,
    canOpenDetail: true,
    rootOrderId: 'root-$id',
    orderNumber: id,
    sellerName: seller,
    primaryProductName: product,
    additionalItemCount: 0,
    productImageUrl: null,
    createdAt: date,
    total: amount,
    currency: 'TRY',
    status: status,
    carrier: null,
    trackingNumber: null,
  );
}

List<String> _ids(List<BuyerOrderListItem> orders, BuyerOrderSort sort) {
  return presentBuyerOrders(
    orders,
    sort: sort,
    statusFilter: BuyerOrderStatusFilter.all,
  ).map((order) => order.sellerOrderId).toList();
}
