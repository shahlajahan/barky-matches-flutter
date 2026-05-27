import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderReturnStatus {
  pending,
  approved,
  rejected,
  shippedBack,
  receivedBySeller,
  refundPending,
  refundFailed,
  refunded,
  cancelled,
}

extension OrderReturnStatusX on OrderReturnStatus {
  String get value {
    switch (this) {
      case OrderReturnStatus.pending:
        return 'pending';
      case OrderReturnStatus.approved:
        return 'approved';
      case OrderReturnStatus.rejected:
        return 'rejected';
      case OrderReturnStatus.shippedBack:
        return 'shipped_back';
      case OrderReturnStatus.receivedBySeller:
        return 'received_by_seller';
      case OrderReturnStatus.refundPending:
        return 'refund_pending';
      case OrderReturnStatus.refundFailed:
        return 'refund_failed';
      case OrderReturnStatus.refunded:
        return 'refunded';
      case OrderReturnStatus.cancelled:
        return 'cancelled';
    }
  }

  static OrderReturnStatus fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'approved':
        return OrderReturnStatus.approved;
      case 'rejected':
        return OrderReturnStatus.rejected;
      case 'shipped_back':
        return OrderReturnStatus.shippedBack;
      case 'received_by_seller':
        return OrderReturnStatus.receivedBySeller;
      case 'refund_pending':
        return OrderReturnStatus.refundPending;
      case 'refund_failed':
        return OrderReturnStatus.refundFailed;
      case 'refunded':
        return OrderReturnStatus.refunded;
      case 'cancelled':
        return OrderReturnStatus.cancelled;
      case 'pending':
      default:
        return OrderReturnStatus.pending;
    }
  }
}

enum OrderReturnReason {
  damaged,
  wrongProduct,
  missingParts,
  notAsDescribed,
  changedMind,
  other,
}

extension OrderReturnReasonX on OrderReturnReason {
  String get value {
    switch (this) {
      case OrderReturnReason.damaged:
        return 'damaged';
      case OrderReturnReason.wrongProduct:
        return 'wrong_product';
      case OrderReturnReason.missingParts:
        return 'missing_parts';
      case OrderReturnReason.notAsDescribed:
        return 'not_as_described';
      case OrderReturnReason.changedMind:
        return 'changed_mind';
      case OrderReturnReason.other:
        return 'other';
    }
  }

  static OrderReturnReason fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'damaged':
        return OrderReturnReason.damaged;
      case 'wrong_product':
        return OrderReturnReason.wrongProduct;
      case 'missing_parts':
        return OrderReturnReason.missingParts;
      case 'not_as_described':
        return OrderReturnReason.notAsDescribed;
      case 'changed_mind':
        return OrderReturnReason.changedMind;
      case 'other':
      default:
        return OrderReturnReason.other;
    }
  }
}

enum RefundType { full, partial, shipping }

extension RefundTypeX on RefundType {
  String get value {
    switch (this) {
      case RefundType.full:
        return 'full';
      case RefundType.partial:
        return 'partial';
      case RefundType.shipping:
        return 'shipping';
    }
  }

  static RefundType fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'partial':
        return RefundType.partial;
      case 'shipping':
        return RefundType.shipping;
      case 'full':
      default:
        return RefundType.full;
    }
  }
}

class OrderReturnItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? imageUrl;

  const OrderReturnItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.imageUrl,
  });

  factory OrderReturnItem.fromMap(Map<String, dynamic> map) {
    final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice =
        (map['unitPrice'] as num?)?.toDouble() ??
        (map['price'] as num?)?.toDouble() ??
        0;
    final lineTotal =
        (map['lineTotal'] as num?)?.toDouble() ?? (unitPrice * quantity);

    return OrderReturnItem(
      productId: (map['productId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      imageUrl: (map['imageUrl'] ?? '').toString().isEmpty
          ? null
          : map['imageUrl'].toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

class OrderReturnRecord {
  final String id;
  final String returnId;
  final String orderId;
  final String sellerOrderId;
  final String rootOrderId;
  final String buyerUid;
  final String sellerUid;
  final String businessId;
  final OrderReturnStatus status;
  final OrderReturnReason reason;
  final String description;
  final List<String> images;
  final List<OrderReturnItem> returnItems;
  final Timestamp? requestedAt;
  final Timestamp? reviewedAt;
  final Timestamp? resolvedAt;
  final Timestamp? refundRequestedAt;
  final Timestamp? refundStartedAt;
  final Timestamp? refundCompletedAt;
  final Timestamp? refundFailedAt;
  final double refundAmount;
  final RefundType refundType;
  final String shippingResponsibility;
  final String? trackingNumber;
  final String? carrier;
  final String? adminNotes;
  final String? sellerNotes;
  final Map<String, dynamic> refundDetails;
  final String? paymentId;
  final int returnWindowDays;
  final int refundRetryCount;
  final String? paymentTransactionId;
  final List<String> paymentTransactionIds;
  final List<Map<String, dynamic>> timeline;

  const OrderReturnRecord({
    required this.id,
    required this.returnId,
    required this.orderId,
    required this.sellerOrderId,
    required this.rootOrderId,
    required this.buyerUid,
    required this.sellerUid,
    required this.businessId,
    required this.status,
    required this.reason,
    required this.description,
    required this.images,
    required this.returnItems,
    required this.requestedAt,
    required this.reviewedAt,
    required this.resolvedAt,
    required this.refundRequestedAt,
    required this.refundStartedAt,
    required this.refundCompletedAt,
    required this.refundFailedAt,
    required this.refundAmount,
    required this.refundType,
    required this.shippingResponsibility,
    required this.trackingNumber,
    required this.carrier,
    required this.adminNotes,
    required this.sellerNotes,
    required this.refundDetails,
    required this.paymentId,
    required this.returnWindowDays,
    required this.refundRetryCount,
    required this.paymentTransactionId,
    required this.paymentTransactionIds,
    required this.timeline,
  });

  factory OrderReturnRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OrderReturnRecord.fromMap(doc.id, data);
  }

  factory OrderReturnRecord.fromMap(String id, Map<String, dynamic> data) {
    final refundDetails = Map<String, dynamic>.from(
      data['refundDetails'] ?? const <String, dynamic>{},
    );
    return OrderReturnRecord(
      id: id,
      returnId: (data['returnId'] ?? id).toString(),
      orderId: (data['orderId'] ?? '').toString(),
      sellerOrderId: (data['sellerOrderId'] ?? '').toString(),
      rootOrderId: (data['rootOrderId'] ?? '').toString(),
      buyerUid: (data['buyerUid'] ?? '').toString(),
      sellerUid: (data['sellerUid'] ?? '').toString(),
      businessId: (data['businessId'] ?? '').toString(),
      status: OrderReturnStatusX.fromString(data['status']?.toString()),
      reason: OrderReturnReasonX.fromString(data['reason']?.toString()),
      description: (data['description'] ?? '').toString(),
      images: List<String>.from(data['images'] ?? const <String>[]),
      returnItems: (data['returnItems'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => OrderReturnItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      requestedAt: data['requestedAt'] as Timestamp?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      resolvedAt: data['resolvedAt'] as Timestamp?,
      refundRequestedAt: data['refundRequestedAt'] as Timestamp?,
      refundStartedAt: data['refundStartedAt'] as Timestamp?,
      refundCompletedAt: data['refundCompletedAt'] as Timestamp?,
      refundFailedAt: data['refundFailedAt'] as Timestamp?,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0,
      refundType: RefundTypeX.fromString(data['refundType']?.toString()),
      shippingResponsibility:
          (data['shippingResponsibility'] ?? 'seller_if_contract_carrier')
              .toString(),
      trackingNumber: (data['trackingNumber'] ?? '').toString().isEmpty
          ? null
          : data['trackingNumber'].toString(),
      carrier: (data['carrier'] ?? '').toString().isEmpty
          ? null
          : data['carrier'].toString(),
      adminNotes: (data['adminNotes'] ?? '').toString().isEmpty
          ? null
          : data['adminNotes'].toString(),
      sellerNotes: (data['sellerNotes'] ?? '').toString().isEmpty
          ? null
          : data['sellerNotes'].toString(),
      refundDetails: refundDetails,
      paymentId:
          (data['paymentId'] ?? refundDetails['paymentId'] ?? '')
              .toString()
              .isEmpty
          ? null
          : (data['paymentId'] ?? refundDetails['paymentId']).toString(),
      returnWindowDays: (data['returnWindowDays'] as num?)?.toInt() ?? 14,
      refundRetryCount: (data['refundRetryCount'] as num?)?.toInt() ?? 0,
      paymentTransactionId:
          (data['paymentTransactionId'] ?? '').toString().isEmpty
          ? null
          : data['paymentTransactionId'].toString(),
      paymentTransactionIds: List<String>.from(
        data['paymentTransactionIds'] ?? const <String>[],
      ),
      timeline: List<Map<String, dynamic>>.from(data['timeline'] ?? const []),
    );
  }

  bool get isClosed =>
      status == OrderReturnStatus.rejected ||
      status == OrderReturnStatus.refunded ||
      status == OrderReturnStatus.cancelled;

  Map<String, dynamic> toMap() => {
    'returnId': returnId,
    'orderId': orderId,
    'sellerOrderId': sellerOrderId,
    'rootOrderId': rootOrderId,
    'buyerUid': buyerUid,
    'sellerUid': sellerUid,
    'businessId': businessId,
    'status': status.value,
    'reason': reason.value,
    'description': description,
    'images': images,
    'returnItems': returnItems.map((e) => e.toMap()).toList(),
    'requestedAt': requestedAt,
    'reviewedAt': reviewedAt,
    'resolvedAt': resolvedAt,
    'refundRequestedAt': refundRequestedAt,
    'refundStartedAt': refundStartedAt,
    'refundCompletedAt': refundCompletedAt,
    'refundFailedAt': refundFailedAt,
    'refundAmount': refundAmount,
    'refundType': refundType.value,
    'shippingResponsibility': shippingResponsibility,
    'trackingNumber': trackingNumber,
    'carrier': carrier,
    'adminNotes': adminNotes,
    'sellerNotes': sellerNotes,
    'refundDetails': refundDetails,
    if (paymentId != null) 'paymentId': paymentId,
    'returnWindowDays': returnWindowDays,
    'refundRetryCount': refundRetryCount,
    'paymentTransactionId': paymentTransactionId,
    'paymentTransactionIds': paymentTransactionIds,
    'timeline': timeline,
  };
}
