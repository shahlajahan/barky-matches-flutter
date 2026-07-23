import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/petshop/pet_shop_profile_data.dart';

void main() {
  group('PetShopProfileData sector matching', () {
    for (final alias in const ['pet_shop', 'petshop', 'seller', 'store']) {
      test('accepts the supported $alias alias', () {
        expect(
          PetShopProfileData.isPetShopBusiness({
            'sectors': [alias],
          }),
          isTrue,
        );
      });
    }

    test('also recognizes an existing pet shop sectorData key', () {
      expect(
        PetShopProfileData.isPetShopBusiness({
          'sectors': <String>[],
          'sectorData': {
            'petshop': {'shopName': 'Paws'},
          },
        }),
        isTrue,
      );
    });

    test('rejects unrelated sectors', () {
      expect(
        PetShopProfileData.isPetShopBusiness({
          'sectors': ['veterinary', 'grooming'],
        }),
        isFalse,
      );
    });
  });

  test('maps the production petshop profile and contact fields', () {
    final shop = PetShopProfileData.fromMap('business-1', {
      'ownerUid': 'seller-owner-1',
      'profile': {'displayName': 'Paws & Co', 'logoUrl': 'logo'},
      'contact': {'city': 'Istanbul', 'district': 'Kadıköy'},
      'sectorData': {
        'petshop': {
          'profile': {'bio': 'Local pet supplies'},
          'categories': ['Food', 'Toys'],
        },
      },
    });

    expect(shop.id, 'business-1');
    expect(shop.name, 'Paws & Co');
    expect(shop.address, 'Kadıköy, Istanbul');
    expect(shop.description, 'Local pet supplies');
    expect(shop.categories, ['Food', 'Toys']);
    expect(shop.productOwnerId, 'seller-owner-1');
  });
}
