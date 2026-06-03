import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/order_return.dart';

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

  Future<void> triggerRefund({
    required String returnId,
    required double refundAmount,
    required String refundType,
    required String paymentId,
    String? notes,
  }) async {
    debugPrint(
      '🔔 seller return action=refund returnId=$returnId amount=$refundAmount',
    );
    await _callCallable('triggerOrderReturnRefund', {
      'returnId': returnId,
      'refundAmount': refundAmount,
      'refundType': refundType,
      'paymentId': paymentId,
      'notes': notes,
    });
  }

  Future<String?> resolvePaymentIdForReturn({required String returnId}) async {
    final returnSnap = await _db
        .collection('order_returns')
        .doc(returnId)
        .get();
    final returnData = returnSnap.data() ?? {};

    String? pickPaymentId(Map<String, dynamic> source) {
      final direct = (source['paymentId'] ?? '').toString().trim();
      if (direct.isNotEmpty) return direct;

      final refundDetails = source['refundDetails'];
      if (refundDetails is Map) {
        final nested = (refundDetails['paymentId'] ?? '').toString().trim();
        if (nested.isNotEmpty) return nested;
      }
      return null;
    }

    final direct = pickPaymentId(returnData);
    if (direct != null && direct.isNotEmpty) {
      debugPrint('🧾 resolvePaymentIdForReturn direct hit returnId=$returnId');
      return direct;
    }

    final sellerOrderId = (returnData['sellerOrderId'] ?? '').toString().trim();
    if (sellerOrderId.isNotEmpty) {
      final sellerSnap = await _db
          .collection('sellerOrders')
          .doc(sellerOrderId)
          .get();
      if (sellerSnap.exists) {
        final sellerData = sellerSnap.data() ?? {};
        final sellerPayment = sellerData['payment'];
        if (sellerPayment is Map) {
          final sellerPaymentId = (sellerPayment['paymentId'] ?? '')
              .toString()
              .trim();
          if (sellerPaymentId.isNotEmpty) {
            debugPrint(
              '🧾 resolvePaymentIdForReturn sellerOrder hit returnId=$returnId sellerOrderId=$sellerOrderId',
            );
            return sellerPaymentId;
          }
        }
      }
    }

    final rootOrderId =
        (returnData['rootOrderId'] ?? returnData['orderId'] ?? '')
            .toString()
            .trim();
    if (rootOrderId.isNotEmpty) {
      final rootSnap = await _db.collection('orders').doc(rootOrderId).get();
      if (rootSnap.exists) {
        final rootData = rootSnap.data() ?? {};
        final rootPayment = rootData['payment'];
        if (rootPayment is Map) {
          final rootPaymentId = (rootPayment['paymentId'] ?? '')
              .toString()
              .trim();
          if (rootPaymentId.isNotEmpty) {
            debugPrint(
              '🧾 resolvePaymentIdForReturn rootOrder hit returnId=$returnId rootOrderId=$rootOrderId',
            );
            return rootPaymentId;
          }
        }
      }
    }

    debugPrint('⚠️ resolvePaymentIdForReturn miss returnId=$returnId');
    return null;
  }
}
