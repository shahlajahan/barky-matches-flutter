import 'dart:async';

import 'package:barky_matches_fixed/ui/orders/buyer_order_list_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

abstract interface class BuyerOrdersDataSource {
  Stream<List<BuyerOrderListItem>> watchBuyerOrders(String buyerUid);
}

class BuyerOrdersRepository implements BuyerOrdersDataSource {
  BuyerOrdersRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<BuyerOrderListItem>> watchBuyerOrders(String buyerUid) {
    final controller = StreamController<List<BuyerOrderListItem>>();
    final subscriptions = <StreamSubscription<QuerySnapshot>>[];
    final buckets = <String, Map<String, BuyerOrderSourceRecord>>{};
    var readyQueries = 0;

    final queries = <({String key, Query query, bool sellerOrder})>[
      for (final field in const ['buyerUid', 'userId'])
        (
          key: 'sellerOrders:$field',
          query: _firestore
              .collection('sellerOrders')
              .where(field, isEqualTo: buyerUid),
          sellerOrder: true,
        ),
      for (final field in const ['buyerUid', 'userId'])
        (
          key: 'orders:$field',
          query: _firestore
              .collection('orders')
              .where(field, isEqualTo: buyerUid),
          sellerOrder: false,
        ),
    ];

    void emit() {
      if (readyQueries < queries.length || controller.isClosed) return;
      final sellerOrders = <BuyerOrderSourceRecord>[];
      final rootOrders = <BuyerOrderSourceRecord>[];
      for (final query in queries) {
        final records = buckets[query.key]?.values ?? const [];
        (query.sellerOrder ? sellerOrders : rootOrders).addAll(records);
      }
      final merged = mergeBuyerOrderRecords(
        sellerOrders: sellerOrders,
        legacyRootOrders: rootOrders,
      );
      debugPrint(
        '🧾 MY_ORDERS buyer=$buyerUid sellerOrders=${sellerOrders.length} '
        'legacyRoots=${rootOrders.length} visible=${merged.length}',
      );
      controller.add(merged);
    }

    controller.onListen = () {
      for (final query in queries) {
        var firstEvent = true;
        subscriptions.add(
          query.query.snapshots().listen(
            (snapshot) {
              buckets[query.key] = {
                for (final document in snapshot.docs)
                  document.id: BuyerOrderSourceRecord(
                    id: document.id,
                    data: Map<String, dynamic>.from(document.data()! as Map),
                    isSellerOrder: query.sellerOrder,
                  ),
              };
              if (firstEvent) {
                readyQueries++;
                firstEvent = false;
              }
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('🧾 MY_ORDERS query=${query.key} error=$error');
              buckets[query.key] = {};
              if (firstEvent) {
                readyQueries++;
                firstEvent = false;
              }
              if (readyQueries == queries.length) emit();
            },
          ),
        );
      }
    };
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await controller.close();
    };
    return controller.stream;
  }
}
