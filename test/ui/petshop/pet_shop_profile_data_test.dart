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

  // ---------------------------------------------------------------------
  // Public-projection schema regression.
  //
  // Both public Petshop surfaces read `businesses_public`, whose projection
  // (functions/src/publicProjections.js) republishes sector details under
  // `publicSectorData` — `sectorData` is deliberately absent from its
  // `PUBLIC_BUSINESS_KEYS` allowlist. A reader that consulted `sectorData`
  // alone therefore rendered name/location/Verified correctly while every
  // sector-scoped field silently fell back to its empty state.
  // ---------------------------------------------------------------------
  group('businesses_public projection schema', () {
    /// The exact shape `buildBusinessPublicProjection` emits for a Petshop
    /// registered through `registerBusiness`: root-level picked keys, a
    /// picked `profile`/`contact`/`verification`, and the sector map under
    /// `publicSectorData` rather than `sectorData`.
    Map<String, dynamic> projectionDocument() => {
      'businessId': 'business-1',
      'sectors': ['pet_shop'],
      'status': 'approved',
      'isActive': true,
      'published': true,
      'isVerified': true,
      'ownerUid': 'seller-owner-1',
      'profile': {'displayName': 'Paws & Co', 'logoUrl': 'logo'},
      'contact': {'city': 'Istanbul', 'district': 'Kadıköy'},
      'verification': {'isVerified': true},
      'publicSectorData': {
        'petshop': {
          'shopName': 'Paws & Co',
          'ownerName': 'Owner',
          'shopTypes': ['Pet Food'],
          'categories': ['Food', 'Toys'],
          'brands': 'BrandA, BrandB',
          'pricing': {'level': 'mid'},
          'sales': {'delivery': 'yes'},
          'workingHours': '09:00-18:00',
          'profile': {'bio': 'Local pet supplies'},
          'promotion': {'hasOffers': 'yes', 'details': '10% off'},
        },
      },
      'projectionVersion': 1,
    };

    test('is detected as a pet shop from the projection sector map', () {
      expect(
        PetShopProfileData.isPetShopBusiness({
          'sectors': <String>[],
          'publicSectorData': {
            'petshop': {'shopName': 'Paws'},
          },
        }),
        isTrue,
      );
    });

    test('reproduces the reported failure surface, then resolves it', () {
      final shop = PetShopProfileData.fromMap(
        'business-1',
        projectionDocument(),
      );

      // Previously correct — these come from root/profile/contact keys the
      // projection does publish, which is why the business looked fine.
      expect(shop.name, 'Paws & Co');
      expect(shop.address, 'Kadıköy, Istanbul');
      expect(shop.isVerified, isTrue);

      // Previously empty — the exact user-reported "No shop description is
      // available." / "No shop categories are available." symptoms.
      expect(shop.description, 'Local pet supplies');
      expect(shop.categories, ['Food', 'Toys']);
      expect(shop.workingHours, isNotNull);
    });

    test('a direct businesses document still wins over a stale projection', () {
      final shop = PetShopProfileData.fromMap('business-1', {
        ...projectionDocument(),
        'sectorData': {
          'petshop': {
            'profile': {'bio': 'Authoritative bio'},
            'categories': ['Authoritative'],
          },
        },
      });

      expect(shop.description, 'Authoritative bio');
      expect(shop.categories, ['Authoritative']);
    });

    test('legacy documents carrying neither key still parse safely', () {
      final shop = PetShopProfileData.fromMap('business-1', {
        'profile': {'displayName': 'Legacy Shop'},
        'contact': {'city': 'Ankara'},
      });

      expect(shop.name, 'Legacy Shop');
      expect(shop.description, isEmpty);
      expect(shop.categories, isEmpty);
    });

    test('malformed sector maps fail safely instead of throwing', () {
      for (final malformed in <dynamic>[
        null,
        'not-a-map',
        42,
        <String>['list'],
        <String, dynamic>{},
      ]) {
        final shop = PetShopProfileData.fromMap('business-1', {
          'profile': {'displayName': 'Paws & Co'},
          'publicSectorData': malformed,
        });
        expect(shop.name, 'Paws & Co');
        expect(shop.categories, isEmpty);
      }
    });

    test('malformed categories inside a valid sector map degrade to empty', () {
      final shop = PetShopProfileData.fromMap('business-1', {
        'publicSectorData': {
          'petshop': {'categories': 'Food, Toys'},
        },
      });

      expect(shop.categories, isEmpty);
    });

    test('shopTypes remains the documented categories fallback', () {
      final shop = PetShopProfileData.fromMap('business-1', {
        'publicSectorData': {
          'petshop': {
            'shopTypes': ['Pet Food'],
          },
        },
      });

      expect(shop.categories, ['Pet Food']);
    });
  });

  // =====================================================================
  // Pinned to the real production projection.
  //
  // The map below is the verbatim `publicSectorData` emitted by
  // `buildBusinessPublicProjection` (functions/src/publicProjections.js) for a
  // Pet Shop registered through the current form — captured from that function,
  // not hand-designed. If the projection allowlist ever drops one of these
  // fields again, this test fails alongside the Functions-side coverage.
  // =====================================================================
  group('real projection output shape', () {
    Map<String, dynamic> realProjection() => {
      'businessId': 'shop-1',
      'sectors': ['pet_shop'],
      'status': 'approved',
      'isVerified': true,
      'verification': {'isVerified': true},
      'profile': {'displayName': 'Paws & Co'},
      'contact': {'city': 'Istanbul', 'district': 'Kadikoy'},
      'publicSectorData': {
        'petshop': {
          'shopName': 'Paws & Co',
          'shopTypes': ['Pet Food'],
          'categories': ['Dry Food'],
          'brands': 'BrandA',
          'pricing': {'level': 'mid'},
          'sales': {
            'delivery': 'yes',
            'onlineOrder': 'no',
            'whatsappOrder': 'yes',
          },
          'workingHours': '10:00\u201321:00',
          'profile': {'bio': 'Local pet supplies'},
          'promotion': {'hasOffers': 'yes', 'details': '10% off'},
        },
      },
    };

    test('the submitted Bio reaches the public model', () {
      final shop = PetShopProfileData.fromMap('shop-1', realProjection());
      expect(shop.description, 'Local pet supplies');
    });

    test('canonical working hours survive to the public model', () {
      final shop = PetShopProfileData.fromMap('shop-1', realProjection());
      expect(shop.workingHours, isNotNull);
      expect(shop.workingHours!['hours'], '10:00\u201321:00');
    });

    test('categories and identity still resolve', () {
      final shop = PetShopProfileData.fromMap('shop-1', realProjection());
      expect(shop.name, 'Paws & Co');
      expect(shop.categories, ['Dry Food']);
      expect(shop.isVerified, isTrue);
    });

    test('empty Bio keeps the honest empty state', () {
      final doc = realProjection();
      (doc['publicSectorData'] as Map)['petshop']['profile'] = {'bio': ''};
      final shop = PetShopProfileData.fromMap('shop-1', doc);
      expect(shop.description, isEmpty);
    });

    test('canonical sector Bio wins over an unrelated legacy alias', () {
      final doc = realProjection();
      // A legacy top-level profile.description must not override the value the
      // seller actually submitted in the Pet Shop form.
      (doc['profile'] as Map)['description'] = 'stale legacy text';
      final shop = PetShopProfileData.fromMap('shop-1', doc);
      expect(shop.description, 'Local pet supplies');
    });

    test('legacy documents with only a top-level bio still resolve', () {
      final shop = PetShopProfileData.fromMap('legacy-1', {
        'profile': {'displayName': 'Legacy', 'bio': 'Legacy bio'},
      });
      expect(shop.description, 'Legacy bio');
    });
  });

  // =====================================================================
  // Working-hours display (residual correction).
  //
  // `forDisplay` previously had no production call site, so the public
  // profile rendered the raw stored value — the reported `10:00_21:00`
  // appeared verbatim. The model now normalizes through the same utility the
  // registration form validates with.
  // =====================================================================
  group('working hours display normalization', () {
    Map<String, dynamic> withHours(dynamic hours) => {
      'profile': {'displayName': 'Shop'},
      'publicSectorData': {
        'petshop': {'workingHours': hours},
      },
    };

    String? hoursOf(dynamic stored) =>
        PetShopProfileData.fromMap(
              's',
              withHours(stored),
            ).workingHours?['hours']
            as String?;

    test('canonical value renders canonically', () {
      expect(hoursOf('10:00\u201321:00'), '10:00\u201321:00');
    });

    test('legacy hyphen value renders canonically', () {
      expect(hoursOf('10:00-21:00'), '10:00\u201321:00');
    });

    test('legacy em dash value renders canonically', () {
      expect(hoursOf('10:00\u201421:00'), '10:00\u201321:00');
    });

    test('single-digit legacy hour renders zero-padded', () {
      expect(hoursOf('9:05-18:30'), '09:05\u201318:30');
    });

    test('the reported underscore value is unavailable, not verbatim', () {
      final shop = PetShopProfileData.fromMap('s', withHours('10:00_21:00'));
      expect(shop.workingHours, isNull);
    });

    test('out-of-range and reversed values are unavailable', () {
      for (final raw in const ['25:00-26:00', '10:60-21:00', '21:00-10:00']) {
        expect(
          PetShopProfileData.fromMap('s', withHours(raw)).workingHours,
          isNull,
          reason: raw,
        );
      }
    });

    test('missing, null and blank values are unavailable', () {
      for (final raw in <dynamic>[null, '', '   ']) {
        expect(
          PetShopProfileData.fromMap('s', withHours(raw)).workingHours,
          isNull,
          reason: '$raw',
        );
      }
      expect(
        PetShopProfileData.fromMap('s', {
          'publicSectorData': {'petshop': <String, dynamic>{}},
        }).workingHours,
        isNull,
      );
    });

    test('a per-day map is passed through unchanged', () {
      final shop = PetShopProfileData.fromMap(
        's',
        withHours({
          'mon': {'hours': '10:00-21:00'},
        }),
      );
      expect(shop.workingHours, isNotNull);
      expect(shop.workingHours!['mon'], isNotNull);
    });
  });
}
