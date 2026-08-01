import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/services/order_return_service.dart';

void main() {
  group('return shipping policy preview', () {
    test('buyer-paid policy requires acknowledgement', () {
      final policy = OrderReturnService.resolveReturnShippingPolicyPreview([
        {'returnShippingPayer': 'buyer', 'hasContractedReturnCarrier': false},
      ]);

      expect(policy.kind, ReturnShippingPolicyKind.buyer);
      expect(
        OrderReturnService.canSubmitWithReturnShippingPolicy(
          policy: policy,
          acknowledged: false,
        ),
        isFalse,
      );
      expect(
        OrderReturnService.canSubmitWithReturnShippingPolicy(
          policy: policy,
          acknowledged: true,
        ),
        isTrue,
      );
    });

    test('seller-paid policy does not require acknowledgement', () {
      final policy = OrderReturnService.resolveReturnShippingPolicyPreview([
        {'returnShippingPayer': 'seller_always'},
      ]);

      expect(policy.kind, ReturnShippingPolicyKind.seller);
      expect(
        OrderReturnService.canSubmitWithReturnShippingPolicy(
          policy: policy,
          acknowledged: false,
        ),
        isTrue,
      );
    });

    test('verified common contracted carrier is displayed', () {
      final policy = OrderReturnService.resolveReturnShippingPolicyPreview([
        {
          'returnShippingPayer': 'seller_if_contract_carrier',
          'hasContractedReturnCarrier': true,
          'returnCarrierCode': 'Yurtici',
        },
        {
          'returnShippingPayer': 'seller_if_contract_carrier',
          'hasContractedReturnCarrier': true,
          'returnCarrierCode': 'Yurtici',
        },
      ]);

      expect(policy.kind, ReturnShippingPolicyKind.contractedCarrier);
      expect(policy.carrierCode, 'Yurtici');
      expect(policy.buyerWarningRequired, isFalse);
    });

    test('unverified contracted policy fails safely to buyer warning', () {
      final policy = OrderReturnService.resolveReturnShippingPolicyPreview([
        {
          'returnShippingPayer': 'seller_if_contract_carrier',
          'hasContractedReturnCarrier': true,
          'returnCarrierCode': '',
        },
      ]);

      expect(policy.kind, ReturnShippingPolicyKind.buyer);
      expect(policy.buyerWarningRequired, isTrue);
    });
  });
}
