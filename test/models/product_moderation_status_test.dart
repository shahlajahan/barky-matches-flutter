import 'package:barky_matches_fixed/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace product compliance audit, P0 remediation (docs/audits/
// marketplace_add_product_compliance_audit_2026-08-20.md, findings
// F-02/F-06). moderationStatus is a new field: a new product defaults to
// pending_review and is never trusted to read back its own prior
// isActive:true as an implicit approval.
void main() {
  test('a new Product defaults to pending_review, not active', () {
    final product = Product(
      id: 'business-1_TEST',
      businessId: 'business-1',
      name: 'Test Product',
      description: 'desc',
      price: 10,
      currency: 'TRY',
      media: const [],
      stock: 1,
      category: 'Health > Vitamins',
      isActive: false,
    );

    expect(product.moderationStatus, 'pending_review');
    expect(product.isActive, isFalse);
  });

  test('moderationStatus round-trips through toJson/fromJson', () {
    final original = Product(
      id: 'business-1_TEST',
      businessId: 'business-1',
      name: 'Test Product',
      description: 'desc',
      price: 10,
      currency: 'TRY',
      media: const [],
      stock: 1,
      category: 'Health > Vitamins',
      isActive: false,
      moderationStatus: 'pending_review',
    );

    final restored = Product.fromJson(original.id, original.toJson());

    expect(restored.moderationStatus, 'pending_review');
    expect(restored.isActive, isFalse);
  });

  test('a legacy document with no moderationStatus field defaults from '
      'isActive for backward compatibility, but never from a fresh write', () {
    final legacyActive = Product.fromJson('legacy-1', {
      'businessId': 'business-1',
      'name': 'Legacy Active',
      'price': 10,
      'stock': 1,
      'category': 'Food > Treats',
      'isActive': true,
    });
    expect(legacyActive.moderationStatus, 'approved');

    final legacyInactive = Product.fromJson('legacy-2', {
      'businessId': 'business-1',
      'name': 'Legacy Inactive',
      'price': 10,
      'stock': 1,
      'category': 'Food > Treats',
      'isActive': false,
    });
    expect(legacyInactive.moderationStatus, 'pending_review');
  });

  test('Product.empty is not active and is pending review', () {
    final empty = Product.empty('placeholder');
    expect(empty.isActive, isFalse);
    expect(empty.moderationStatus, 'pending_review');
  });
}
