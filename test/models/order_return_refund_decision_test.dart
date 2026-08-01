import 'package:barky_matches_fixed/models/order_return.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buyer-facing refund decision fields remain readable', () {
    final record = OrderReturnRecord.fromMap('return-1', {
      'status': 'refund_rejected',
      'refundAmount': 0,
      'refundDecisionType': 'REJECTED',
      'refundReason': 'Customer caused damage',
      'refundReasonCode': 'customer_caused_damage',
      'refundExplanation': 'The returned item was damaged after delivery.',
      'refundDifference': 100,
    });

    expect(record.status, OrderReturnStatus.refundRejected);
    expect(record.refundDecisionType, 'REJECTED');
    expect(record.refundReasonCode, 'customer_caused_damage');
    expect(
      record.refundExplanation,
      'The returned item was damaged after delivery.',
    );
    expect(record.refundDifference, 100);
    expect(record.isClosed, isTrue);
  });

  test('new return completion states remain readable', () {
    final waiting = OrderReturnRecord.fromMap('return-2', {
      'status': 'waiting_for_seller_confirmation',
      'autoReceived': false,
    });
    final automatic = OrderReturnRecord.fromMap('return-3', {
      'status': 'auto_received',
      'autoReceived': true,
    });
    final dispute = OrderReturnRecord.fromMap('return-4', {
      'status': 'dispute',
      'disputeReasonCode': 'tracking_issue',
      'disputeReason': 'Tracking issue',
    });

    expect(
      waiting.status,
      OrderReturnStatus.waitingForSellerConfirmation,
    );
    expect(automatic.status, OrderReturnStatus.autoReceived);
    expect(automatic.autoReceived, isTrue);
    expect(dispute.status, OrderReturnStatus.dispute);
    expect(dispute.disputeReasonCode, 'tracking_issue');
  });
}
