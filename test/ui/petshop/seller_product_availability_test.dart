import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/petshop/seller_product_availability.dart';

/// "Buy Now" previously navigated unconditionally, so a Pet Shop with no
/// published products sent every visitor into an empty catalogue. Availability
/// is resolved with the same two conditions the customer catalogue and
/// `firestore.rules` both require for a non-owner to see a product.
void main() {
  Future<void> seed(
    FakeFirebaseFirestore db,
    String sellerId,
    List<Map<String, dynamic>> products,
  ) async {
    for (var i = 0; i < products.length; i++) {
      await db
          .collection('businesses')
          .doc(sellerId)
          .collection('products')
          .doc('p$i')
          .set(products[i]);
    }
  }

  test('no products at all resolves to none', () async {
    final db = FakeFirebaseFirestore();
    expect(
      await resolveSellerProductAvailability('shop-1', firestore: db),
      SellerProductAvailability.none,
    );
  });

  test(
    'one genuinely customer-visible product resolves to available',
    () async {
      final db = FakeFirebaseFirestore();
      await seed(db, 'shop-1', [
        {'isActive': true, 'moderationStatus': 'approved'},
      ]);
      expect(
        await resolveSellerProductAvailability('shop-1', firestore: db),
        SellerProductAvailability.available,
      );
    },
  );

  test('drafts, pending, rejected, revoked and inactive stay hidden', () async {
    final db = FakeFirebaseFirestore();
    await seed(db, 'shop-1', [
      {'isActive': false, 'moderationStatus': 'approved'}, // unpublished
      {'isActive': true, 'moderationStatus': 'pending_review'}, // pending
      {'isActive': true, 'moderationStatus': 'rejected'}, // rejected
      {'isActive': true, 'moderationStatus': 'draft'}, // draft
      {'isActive': false, 'moderationStatus': 'pending_review'}, // revoked
    ]);
    expect(
      await resolveSellerProductAvailability('shop-1', firestore: db),
      SellerProductAvailability.none,
    );
  });

  test('a single visible product among hidden ones is enough', () async {
    final db = FakeFirebaseFirestore();
    await seed(db, 'shop-1', [
      {'isActive': true, 'moderationStatus': 'pending_review'},
      {'isActive': true, 'moderationStatus': 'approved'},
      {'isActive': false, 'moderationStatus': 'approved'},
    ]);
    expect(
      await resolveSellerProductAvailability('shop-1', firestore: db),
      SellerProductAvailability.available,
    );
  });

  test('another seller\'s visible product does not count', () async {
    final db = FakeFirebaseFirestore();
    await seed(db, 'other-shop', [
      {'isActive': true, 'moderationStatus': 'approved'},
    ]);
    expect(
      await resolveSellerProductAvailability('shop-1', firestore: db),
      SellerProductAvailability.none,
    );
  });

  test('blank or null seller id fails closed', () async {
    final db = FakeFirebaseFirestore();
    for (final id in <String?>[null, '', '   ']) {
      expect(
        await resolveSellerProductAvailability(id, firestore: db),
        SellerProductAvailability.none,
        reason: '$id',
      );
    }
  });

  test('a query failure fails closed instead of throwing', () async {
    expect(
      await resolveSellerProductAvailability(
        'shop-1',
        firestore: _ThrowingFirestore(),
      ),
      SellerProductAvailability.none,
    );
  });

  test('unknown is never a resolved outcome', () async {
    final db = FakeFirebaseFirestore();
    await seed(db, 'shop-1', [
      {'isActive': true, 'moderationStatus': 'approved'},
    ]);
    // `unknown` exists only as the pre-resolution UI state; the resolver
    // always returns a decided value so the button cannot flash.
    expect(
      await resolveSellerProductAvailability('shop-1', firestore: db),
      isNot(SellerProductAvailability.unknown),
    );
    expect(
      await resolveSellerProductAvailability('missing', firestore: db),
      isNot(SellerProductAvailability.unknown),
    );
  });
}

/// Simulates a permission-denied / offline read.
class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}
