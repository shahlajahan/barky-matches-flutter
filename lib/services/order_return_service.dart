import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/order_return.dart';

enum ReturnShippingPolicyKind { buyer, seller, contractedCarrier }

class ReturnShippingPolicyPreview {
  final ReturnShippingPolicyKind kind;
  final String? carrierCode;

  const ReturnShippingPolicyPreview({required this.kind, this.carrierCode});

  bool get buyerWarningRequired => kind == ReturnShippingPolicyKind.buyer;
}

class RefundPolicyAmounts {
  final double originalOrderAmount;
  final double returnItemsAmount;
  final double outboundShippingAmount;

  const RefundPolicyAmounts({
    required this.originalOrderAmount,
    required this.returnItemsAmount,
    required this.outboundShippingAmount,
  });

  double get fullEligibleAmount => (returnItemsAmount + outboundShippingAmount)
      .clamp(0, originalOrderAmount);

  double get partialEligibleAmount =>
      returnItemsAmount.clamp(0, originalOrderAmount);
}

class OrderReturnService {
  OrderReturnService._();

  static final OrderReturnService instance = OrderReturnService._();
  static const String _region = 'europe-west3';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: _region,
  );

  void _logCallableInit(String callableName) {
    debugPrint('🔧 Functions callable init');
    debugPrint('🔧 callable=$callableName');
    debugPrint('🔧 region=$_region');
    debugPrint('🔧 init=${_functions.runtimeType}');
  }

  Future<HttpsCallableResult<Object?>> _callCallable(
    String callableName,
    Map<String, dynamic> data,
  ) async {
    _logCallableInit(callableName);
    return _functions.httpsCallable(callableName).call(data);
  }

  Stream<List<OrderReturnRecord>> watchBuyerReturns({
    required String buyerUid,
    String? sellerOrderId,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('order_returns')
        .where('buyerUid', isEqualTo: buyerUid);

    if (sellerOrderId != null && sellerOrderId.isNotEmpty) {
      query = query.where('sellerOrderId', isEqualTo: sellerOrderId);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(OrderReturnRecord.fromDoc).toList()..sort((a, b) {
            final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          }),
    );
  }

  Stream<List<OrderReturnRecord>> watchSellerReturns({
    required String businessId,
  }) {
    return _db
        .collection('order_returns')
        .where('businessId', isEqualTo: businessId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(OrderReturnRecord.fromDoc).toList(),
        );
  }

  Stream<List<OrderReturnRecord>> watchSellerOrderReturns({
    required String sellerOrderId,
    String? buyerUid,
    String? businessId,
  }) {
    debugPrint(
      '🧾 watchSellerOrderReturns query sellerOrderId=$sellerOrderId '
      'buyerUid=${buyerUid ?? "null"} businessId=${businessId ?? "null"}',
    );

    Query<Map<String, dynamic>> query = _db
        .collection('order_returns')
        .where('sellerOrderId', isEqualTo: sellerOrderId);

    if (buyerUid != null && buyerUid.isNotEmpty) {
      query = query.where('buyerUid', isEqualTo: buyerUid);
    }

    if (businessId != null && businessId.isNotEmpty) {
      query = query.where('businessId', isEqualTo: businessId);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(OrderReturnRecord.fromDoc).toList()..sort((a, b) {
            final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          }),
    );
  }

  static ReturnShippingPolicyPreview resolveReturnShippingPolicyPreview(
    List<Map<String, dynamic>> products,
  ) {
    final policies = products
        .map(
          (product) =>
              (product['returnShippingPayer'] ?? 'seller_if_contract_carrier')
                  .toString()
                  .trim()
                  .toLowerCase(),
        )
        .toList();

    if (policies.contains('buyer')) {
      return const ReturnShippingPolicyPreview(
        kind: ReturnShippingPolicyKind.buyer,
      );
    }
    if (policies.any(
      (policy) => policy == 'seller' || policy == 'seller_always',
    )) {
      return const ReturnShippingPolicyPreview(
        kind: ReturnShippingPolicyKind.seller,
      );
    }

    final carrierCodes = products
        .map(
          (product) => (product['returnCarrierCode'] ?? '').toString().trim(),
        )
        .toList();
    final normalizedCarriers = carrierCodes
        .where((carrier) => carrier.isNotEmpty)
        .map((carrier) => carrier.toLowerCase())
        .toSet();
    final allContracted =
        products.isNotEmpty &&
        products.every(
          (product) =>
              product['hasContractedReturnCarrier'] == true &&
              (product['returnCarrierCode'] ?? '').toString().trim().isNotEmpty,
        ) &&
        normalizedCarriers.length == 1;

    if (allContracted) {
      return ReturnShippingPolicyPreview(
        kind: ReturnShippingPolicyKind.contractedCarrier,
        carrierCode: carrierCodes.first,
      );
    }

    return const ReturnShippingPolicyPreview(
      kind: ReturnShippingPolicyKind.buyer,
    );
  }

  static bool canSubmitWithReturnShippingPolicy({
    required ReturnShippingPolicyPreview? policy,
    required bool acknowledged,
  }) {
    return policy != null && (!policy.buyerWarningRequired || acknowledged);
  }

  Future<ReturnShippingPolicyPreview> loadReturnShippingPolicyPreview({
    required String businessId,
    required Iterable<String> productIds,
  }) async {
    final uniqueProductIds = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (businessId.trim().isEmpty || uniqueProductIds.isEmpty) {
      return const ReturnShippingPolicyPreview(
        kind: ReturnShippingPolicyKind.buyer,
      );
    }

    final products = <Map<String, dynamic>>[];
    for (final productId in uniqueProductIds) {
      // P0 gap review item 4: the caller here is the buyer requesting a
      // return, not the product owner. If the product was
      // unpublished/suspended since the order was placed, the products
      // read rule (moderationStatus=='approved' && isActive==true for a
      // non-owner) now makes this get() throw permission-denied instead
      // of returning exists:false — treat both the same way this method
      // already treats a missing product.
      DocumentSnapshot<Map<String, dynamic>>? snapshot;
      try {
        snapshot = await _db
            .collection('businesses')
            .doc(businessId)
            .collection('products')
            .doc(productId)
            .get();
      } on FirebaseException {
        snapshot = null;
      }
      if (snapshot == null || !snapshot.exists) {
        return const ReturnShippingPolicyPreview(
          kind: ReturnShippingPolicyKind.buyer,
        );
      }
      products.add(snapshot.data() ?? const <String, dynamic>{});
    }

    return resolveReturnShippingPolicyPreview(products);
  }

  Future<String> createReturnRequest({
    required String sellerOrderId,
    required String rootOrderId,
    required String buyerUid,
    required String sellerUid,
    required String businessId,
    required String reason,
    required String description,
    required List<Map<String, dynamic>> returnItems,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
    required List<String> imageContentTypes,
    required String refundType,
    required String shippingResponsibility,
    required num refundAmount,
    required int returnWindowDays,
    required bool buyerAcknowledgedReturnShipping,
  }) async {
    debugPrint('🔄 return creation started');
    debugPrint('🧾 sellerOrderId=$sellerOrderId');
    debugPrint('🧾 rootOrderId=$rootOrderId');
    debugPrint('🧾 buyerUid=$buyerUid');
    debugPrint('🧾 sellerUid=$sellerUid');
    debugPrint('🧾 businessId=$businessId');

    final images = <Map<String, String>>[];
    for (var i = 0; i < imageBytes.length; i++) {
      final bytes = imageBytes[i];
      images.add({
        'name': i < imageNames.length ? imageNames[i] : 'image_$i.jpg',
        'contentType': i < imageContentTypes.length
            ? imageContentTypes[i]
            : 'image/jpeg',
        'base64': base64Encode(bytes),
      });
    }

    final result = await _callCallable('createOrderReturnRequest', {
      'sellerOrderId': sellerOrderId,
      'rootOrderId': rootOrderId,
      'buyerUid': buyerUid,
      'sellerUid': sellerUid,
      'businessId': businessId,
      'reason': reason,
      'description': description,
      'returnItems': returnItems,
      'images': images,
      'refundType': refundType,
      'shippingResponsibility': shippingResponsibility,
      'refundAmount': refundAmount,
      'returnWindowDays': returnWindowDays,
      'buyerAcknowledgedReturnShipping': buyerAcknowledgedReturnShipping,
    });

    final returnData = result.data;
    final returnId = returnData is Map
        ? (returnData['returnId'] ?? '').toString()
        : '';
    debugPrint('✅ return creation success returnId=$returnId');
    return returnId;
  }

  Future<void> approveReturn({
    required String returnId,
    String? notes,
    String? shippingResponsibility,
  }) async {
    debugPrint('🔔 seller return action=approve returnId=$returnId');
    await _callCallable('reviewOrderReturnRequest', {
      'returnId': returnId,
      'action': 'approved',
      'notes': notes,
      'shippingResponsibility': shippingResponsibility,
    });
  }

  Future<void> rejectReturn({
    required String returnId,
    required String notes,
  }) async {
    debugPrint('🔔 seller return action=reject returnId=$returnId');
    await _callCallable('reviewOrderReturnRequest', {
      'returnId': returnId,
      'action': 'rejected',
      'notes': notes,
    });
  }

  Future<void> cancelReturn({required String returnId, String? notes}) async {
    debugPrint('🔔 buyer return action=cancel returnId=$returnId');
    await _callCallable('cancelOrderReturnRequest', {
      'returnId': returnId,
      'notes': notes,
    });
  }

  Future<void> markShippedBack({
    required String returnId,
    required String trackingNumber,
    required String carrier,
    String? notes,
  }) async {
    debugPrint('🔔 buyer return action=shipped_back returnId=$returnId');
    final payload = {
      'returnId': returnId,
      'trackingNumber': trackingNumber.trim(),
      'carrier': carrier.trim(),
      'notes': notes,
    };
    debugPrint('🚚 shippedBack payload: $payload');
    await _callCallable('markOrderReturnShippedBack', payload);
  }

  Future<String?> resolveOriginalCarrierForReturn({
    required String sellerOrderId,
    required String rootOrderId,
  }) async {
    try {
      final sellerSnap = await _db
          .collection('sellerOrders')
          .doc(sellerOrderId)
          .get();
      if (sellerSnap.exists) {
        final sellerCarrier = (sellerSnap.data()?['shipping']?['carrier'] ?? '')
            .toString()
            .trim();
        if (sellerCarrier.isNotEmpty) {
          debugPrint(
            '🚚 resolveOriginalCarrierForReturn sellerOrder hit sellerOrderId=$sellerOrderId carrier=$sellerCarrier',
          );
          return sellerCarrier;
        }
      }

      if (rootOrderId.isNotEmpty) {
        final rootSnap = await _db.collection('orders').doc(rootOrderId).get();
        if (rootSnap.exists) {
          final rootCarrier = (rootSnap.data()?['shipping']?['carrier'] ?? '')
              .toString()
              .trim();
          if (rootCarrier.isNotEmpty) {
            debugPrint(
              '🚚 resolveOriginalCarrierForReturn rootOrder hit rootOrderId=$rootOrderId carrier=$rootCarrier',
            );
            return rootCarrier;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ resolveOriginalCarrierForReturn failed: $e');
    }
    return null;
  }

  Future<void> markReceived({required String returnId, String? notes}) async {
    debugPrint('🔔 seller return action=received_by_seller returnId=$returnId');
    await _callCallable('markOrderReturnReceived', {
      'returnId': returnId,
      'notes': notes,
    });
  }

  Future<void> reportReturnProblem({
    required String returnId,
    required String disputeReasonCode,
    required String sellerNotes,
  }) async {
    await _callCallable('reportOrderReturnProblem', {
      'returnId': returnId,
      'disputeReasonCode': disputeReasonCode,
      'sellerNotes': sellerNotes,
    });
  }

  Future<RefundPolicyAmounts> loadRefundPolicyAmounts({
    required OrderReturnRecord record,
  }) async {
    final sellerOrderSnap = await _db
        .collection('sellerOrders')
        .doc(record.sellerOrderId)
        .get();
    final sellerOrder = sellerOrderSnap.data() ?? const <String, dynamic>{};
    final payment = sellerOrder['payment'] is Map
        ? Map<String, dynamic>.from(sellerOrder['payment'] as Map)
        : const <String, dynamic>{};
    final pricing = sellerOrder['pricing'] is Map
        ? Map<String, dynamic>.from(sellerOrder['pricing'] as Map)
        : const <String, dynamic>{};
    final financial = sellerOrder['financial'] is Map
        ? Map<String, dynamic>.from(sellerOrder['financial'] as Map)
        : const <String, dynamic>{};
    final shipping = sellerOrder['shipping'] is Map
        ? Map<String, dynamic>.from(sellerOrder['shipping'] as Map)
        : const <String, dynamic>{};
    final originalOrderAmount =
        (payment['paidPrice'] ??
                pricing['grandTotal'] ??
                financial['grossAmount'] ??
                payment['price'] ??
                0)
            as num;
    final outboundShippingAmount =
        (pricing['shippingTotal'] ??
                shipping['price'] ??
                shipping['amount'] ??
                0)
            as num;
    final returnItemsAmount = record.returnItems.fold<double>(
      0,
      (total, item) => total + item.lineTotal,
    );

    return RefundPolicyAmounts(
      originalOrderAmount: originalOrderAmount.toDouble(),
      returnItemsAmount: returnItemsAmount,
      outboundShippingAmount: outboundShippingAmount.toDouble(),
    );
  }

  Future<void> triggerRefund({
    required String returnId,
    required double refundAmount,
    required String refundType,
    RefundReference? refundReference,
    required String refundDecisionType,
    required String refundReasonCode,
    required String sellerDecisionNotes,
    required String refundExplanation,
  }) async {
    debugPrint(
      '🔔 seller return action=refund returnId=$returnId amount=$refundAmount '
      'provider=${refundReference?.provider ?? "none"}',
    );
    await _callCallable('triggerOrderReturnRefund', {
      'returnId': returnId,
      'refundAmount': refundAmount,
      'refundType': refundType,
      if (refundReference != null) 'refundReference': refundReference.toMap(),
      'refundDecisionType': refundDecisionType,
      'refundReasonCode': refundReasonCode,
      'sellerDecisionNotes': sellerDecisionNotes,
      'refundExplanation': refundExplanation,
      'notes': sellerDecisionNotes,
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeGet(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    const delays = [
      Duration(milliseconds: 400),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];

    for (var i = 0; i < delays.length; i++) {
      try {
        return await ref.get();
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') rethrow;

        debugPrint('Firestore unavailable. Retry ${i + 1}/${delays.length}');

        await Future.delayed(delays[i]);
      }
    }

    return null;
  }

  Future<RefundReference?> resolveRefundReferenceForReturn({
    required String returnId,
  }) async {
    final returnSnap = await _safeGet(
      _db.collection('order_returns').doc(returnId),
    );

    if (returnSnap == null || !returnSnap.exists) {
      debugPrint(
        '⚠️ resolveRefundReferenceForReturn: return not found/unavailable returnId=$returnId',
      );
      return null;
    }

    final returnData = returnSnap.data() ?? {};

    RefundReference? fromSource(Map<String, dynamic> source) {
      final reference = RefundReference.fromMap(source);
      return reference.hasIdentifier ? reference : null;
    }

    final direct = fromSource(returnData);
    if (direct != null) {
      debugPrint(
        '🧾 resolveRefundReferenceForReturn direct hit returnId=$returnId '
        'provider=${direct.provider}',
      );
      return direct;
    }

    final refundDetails = returnData['refundDetails'];
    if (refundDetails is Map) {
      final fromDetails = fromSource(Map<String, dynamic>.from(refundDetails));
      if (fromDetails != null) {
        debugPrint(
          '🧾 resolveRefundReferenceForReturn refundDetails hit returnId=$returnId '
          'provider=${fromDetails.provider}',
        );
        return fromDetails;
      }
    }

    final sellerOrderId = (returnData['sellerOrderId'] ?? '').toString().trim();

    if (sellerOrderId.isNotEmpty) {
      final sellerSnap = await _safeGet(
        _db.collection('sellerOrders').doc(sellerOrderId),
      );

      if (sellerSnap != null && sellerSnap.exists) {
        final sellerPayment = sellerSnap.data()?['payment'];
        if (sellerPayment is Map) {
          final fromSeller = fromSource(
            Map<String, dynamic>.from(sellerPayment),
          );
          if (fromSeller != null) {
            debugPrint(
              '🧾 resolveRefundReferenceForReturn sellerOrder hit '
              'returnId=$returnId sellerOrderId=$sellerOrderId '
              'provider=${fromSeller.provider}',
            );
            return fromSeller;
          }
        }
      }
    }

    final rootOrderId =
        (returnData['rootOrderId'] ?? returnData['orderId'] ?? '')
            .toString()
            .trim();

    if (rootOrderId.isNotEmpty) {
      final rootSnap = await _safeGet(
        _db.collection('orders').doc(rootOrderId),
      );

      if (rootSnap != null && rootSnap.exists) {
        final rootPayment = rootSnap.data()?['payment'];
        if (rootPayment is Map) {
          final fromRoot = fromSource(Map<String, dynamic>.from(rootPayment));
          if (fromRoot != null) {
            debugPrint(
              '🧾 resolveRefundReferenceForReturn rootOrder hit '
              'returnId=$returnId rootOrderId=$rootOrderId '
              'provider=${fromRoot.provider}',
            );
            return fromRoot;
          }
        }
      }
    }

    debugPrint('⚠️ resolveRefundReferenceForReturn miss returnId=$returnId');

    return null;
  }
}
