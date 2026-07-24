import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Product round-trips all checkout shipping configuration', () {
    final original = Product(
      id: 'business-1_DENTASTIK',
      businessId: 'business-1',
      name: 'Dentastik',
      description: 'Dental snack',
      price: 10,
      currency: 'TRY',
      media: const [],
      stock: 5,
      category: 'Food > Treats',
      isActive: true,
      shippingMode: 'free_shipping',
      shippingPayer: 'seller',
      shippingFee: 0,
      freeShippingThreshold: 100,
      allowFreeShipping: false,
      allowedCarrierCodes: const ['YURTICI', 'ARAS'],
      weightKg: 0.5,
      lengthCm: 20,
      widthCm: 10,
      heightCm: 5,
      fixedDesi: 1,
    );

    final restored = Product.fromJson(original.id, original.toJson());

    expect(restored.shippingMode, 'free_shipping');
    expect(restored.shippingPayer, 'seller');
    expect(restored.shippingFee, 0);
    expect(restored.freeShippingThreshold, 100);
    expect(restored.allowFreeShipping, isFalse);
    expect(restored.allowedCarrierCodes, ['YURTICI', 'ARAS']);
    expect(restored.weightKg, 0.5);
    expect(restored.fixedDesi, 1);
    expect(restored.isFreeShipping(0), isTrue);
    expect(restored.requiresCarrierEstimate, isFalse);
  });

  test('CartItem payload retains product shipping fields for presentation', () {
    final product = Product(
      id: 'business-1_DENTASTIK',
      businessId: 'business-1',
      name: 'Dentastik',
      description: 'Dental snack',
      price: 10,
      currency: 'TRY',
      media: const [],
      stock: 5,
      category: 'Food > Treats',
      isActive: true,
      shippingMode: 'free_shipping',
      shippingPayer: 'seller',
      allowedCarrierCodes: const ['YURTICI'],
    );
    final payload = CartItem(
      productId: product.id,
      shopId: product.businessId,
      name: product.name,
      price: product.price,
      quantity: 1,
      product: product,
    ).toJson();

    expect(payload['shippingMode'], 'free_shipping');
    expect(payload['shippingPayer'], 'seller');
    expect(payload['allowedCarrierCodes'], ['YURTICI']);
    expect((payload['product'] as Map)['shippingMode'], 'free_shipping');
  });
}
