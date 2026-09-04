import 'package:barky_matches_fixed/ui/business/petshop/product_save_plan.dart';
import 'package:barky_matches_fixed/ui/business/petshop/product_submit_exception.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// The product-submission error contract: a frozen set of machine-readable
/// reason codes, and an extractor that must never let a known failure fall
/// through to the generic "something went wrong" message.
void main() {
  group('frozen reason codes', () {
    test('exactly the eight documented codes exist', () {
      expect(ProductSubmissionReason.values, {
        'marketplace_disabled',
        'seller_activation_required',
        'invalid_seller_relationship',
        'invalid_product_data',
        'duplicate_sku',
        'permission_denied',
        'upload_failed',
        'product_submission_failed',
      });
    });

    test('each constant matches its wire value', () {
      expect(
        ProductSubmissionReason.marketplaceDisabled,
        'marketplace_disabled',
      );
      expect(
        ProductSubmissionReason.sellerActivationRequired,
        'seller_activation_required',
      );
      expect(
        ProductSubmissionReason.invalidSellerRelationship,
        'invalid_seller_relationship',
      );
      expect(
        ProductSubmissionReason.invalidProductData,
        'invalid_product_data',
      );
      expect(ProductSubmissionReason.duplicateSku, 'duplicate_sku');
      expect(ProductSubmissionReason.permissionDenied, 'permission_denied');
      expect(ProductSubmissionReason.uploadFailed, 'upload_failed');
      expect(
        ProductSubmissionReason.productSubmissionFailed,
        'product_submission_failed',
      );
    });
  });

  group('productSubmissionReasonOf', () {
    test('extracts a recognized reasonCode from callable details', () {
      final error = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Marketplace is not enabled',
        details: const {'reasonCode': 'marketplace_disabled'},
      );
      expect(productSubmissionReasonOf(error), 'marketplace_disabled');
    });

    test('every frozen code round-trips through details', () {
      for (final reason in ProductSubmissionReason.values) {
        final error = FirebaseFunctionsException(
          code: 'internal',
          message: 'x',
          details: {'reasonCode': reason},
        );
        expect(
          productSubmissionReasonOf(error),
          reason,
          reason: '$reason must survive extraction',
        );
      }
    });

    test('an unrecognized reasonCode falls back to the raw callable code', () {
      final error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'x',
        details: const {'reasonCode': 'not_a_frozen_code'},
      );
      expect(productSubmissionReasonOf(error), 'permission-denied');
    });

    test('a bare FirebaseException yields its code rather than null', () {
      // The regression this contract closes: a Firestore permission-denied
      // previously produced no code at all, so the UI showed only the
      // generic message for a precisely-identified authorization failure.
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'The caller does not have permission.',
      );
      expect(productSubmissionReasonOf(error), 'permission-denied');
    });

    test('a callable exception with no details yields its code', () {
      final error = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'backend unavailable',
      );
      expect(productSubmissionReasonOf(error), 'unavailable');
    });

    test('legacy ProductSubmitException codes are preserved', () {
      for (final code in [
        'sku-locked',
        'business-not-found',
        'marketplace-seller-inactive',
        'original-product-missing',
      ]) {
        expect(productSubmissionReasonOf(ProductSubmitException(code)), code);
      }
    });

    test('a genuinely unknown error yields null', () {
      expect(productSubmissionReasonOf(Exception('boom')), isNull);
      expect(productSubmissionReasonOf(StateError('boom')), isNull);
    });

    test('a non-map details payload is ignored safely', () {
      final error = FirebaseFunctionsException(
        code: 'internal',
        message: 'x',
        details: 'not-a-map',
      );
      expect(productSubmissionReasonOf(error), 'internal');
    });
  });
}
