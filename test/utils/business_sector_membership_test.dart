import 'package:barky_matches_fixed/ui/petshop/pet_shop_profile_data.dart';
import 'package:barky_matches_fixed/utils/business_sector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-sector list membership.
///
/// A Pet Shop that legitimately sells grooming products — `shopTypes`
/// containing "Grooming" — was listed as a Groomy business, because the
/// Groomy reader stringified the whole `publicSectorData` map and searched it
/// for the substring "groom". Pet Hotel carried the identical defect for
/// "hotel"/"boarding"/"pansiyon", and both now share one canonical predicate:
/// [BusinessSector.belongsToSector].
///
/// Sector membership may come only from the canonical `sectors` array or from
/// a sector-detail map key that itself normalizes to the sector. Product data
/// — shop types, categories, brands, tags, service names, free text — is never
/// membership evidence.
void main() {
  bool isGroomy(Map<String, dynamic> business) =>
      BusinessSector.belongsToSector(business, BusinessSector.groomy);

  bool isPetHotel(Map<String, dynamic> business) =>
      BusinessSector.belongsToSector(business, BusinessSector.petHotel);

  group('Groomy membership', () {
    test('canonical sectors ["groomy"] is included', () {
      expect(
        isGroomy({
          'sectors': ['groomy'],
        }),
        isTrue,
      );
    });

    test('recognized canonical sector aliases are included', () {
      for (final alias in ['groomy', 'groomer', 'grooming', 'pet grooming']) {
        expect(
          isGroomy({
            'sectors': [alias],
          }),
          isTrue,
          reason: 'sectors: [$alias] must be a Groomy business',
        );
      }
    });

    test(
      'legacy publicSectorData.groomy key with empty sectors is included',
      () {
        expect(
          isGroomy({
            'sectors': <String>[],
            'publicSectorData': {
              'groomy': {'services': <dynamic>[]},
            },
          }),
          isTrue,
        );
      },
    );

    test('legacy sector-map key aliases are included', () {
      for (final key in ['groomy', 'groomer', 'grooming']) {
        expect(
          isGroomy({
            'publicSectorData': {
              key: {'services': <dynamic>[]},
            },
          }),
          isTrue,
          reason: 'publicSectorData.$key must be a Groomy business',
        );
        expect(
          isGroomy({
            'sectorData': {
              key: {'services': <dynamic>[]},
            },
          }),
          isTrue,
          reason: 'sectorData.$key must be a Groomy business',
        );
      }
    });

    test('Pet Shop with shopTypes ["Grooming"] is excluded', () {
      expect(
        isGroomy({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {
              'shopName': 'Pharos',
              'shopTypes': ['Pet Food', 'Grooming'],
            },
          },
        }),
        isFalse,
      );
    });

    test('Pet Shop with categories containing "Grooming" is excluded', () {
      expect(
        isGroomy({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {
              'categories': ['Toys', 'Grooming Tools'],
            },
          },
        }),
        isFalse,
      );
    });

    test('Pet Shop with brand free text containing "groom" is excluded', () {
      expect(
        isGroomy({
          'sectors': ['pet_shop'],
          'profile': {
            'categories': ['GroomPro'],
            'tags': ['grooming'],
          },
          'publicSectorData': {
            'petshop': {'brands': 'GroomPro Supplies'},
          },
        }),
        isFalse,
      );
    });

    test('Pet Shop description containing "kuaf" is excluded', () {
      expect(
        isGroomy({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {
              'profileContent': {'bio': 'Kuafor malzemeleri satiyoruz'},
            },
          },
        }),
        isFalse,
      );
    });

    test('canonical businesses of every other sector are excluded', () {
      for (final sector in [
        'vet',
        'pet_shop',
        'pet_hotel',
        'pet_taxi',
        'adoption_center',
        'training',
      ]) {
        expect(
          isGroomy({
            'sectors': [sector],
            'publicSectorData': {
              sector: {'services': <dynamic>[]},
            },
          }),
          isFalse,
          reason: 'a $sector business must not be a Groomy business',
        );
      }
    });
  });

  group('Pet Hotel membership', () {
    test('canonical sectors ["pet_hotel"] is included', () {
      expect(
        isPetHotel({
          'sectors': ['pet_hotel'],
        }),
        isTrue,
      );
    });

    test('recognized canonical sector aliases are included', () {
      for (final alias in [
        'pet_hotel',
        'pet hotel',
        'petHotel',
        'hotel',
        'boarding',
        'pet boarding',
      ]) {
        expect(
          isPetHotel({
            'sectors': [alias],
          }),
          isTrue,
          reason: 'sectors: [$alias] must be a Pet Hotel business',
        );
      }
    });

    test('legacy sector-map keys are included', () {
      for (final key in ['pet_hotel', 'petHotel', 'hotel']) {
        expect(
          isPetHotel({
            'sectors': <String>[],
            'publicSectorData': {
              key: {'amenities': <dynamic>[]},
            },
          }),
          isTrue,
          reason: 'publicSectorData.$key must be a Pet Hotel business',
        );
      }
    });

    test('unrelated business with nested "hotel" text is excluded', () {
      expect(
        isPetHotel({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {'brands': 'Hotel Collection'},
          },
        }),
        isFalse,
      );
    });

    test('unrelated business with nested "boarding" text is excluded', () {
      expect(
        isPetHotel({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {
              'categories': ['Boarding Accessories'],
            },
          },
        }),
        isFalse,
      );
    });

    test('unrelated business with nested "pansiyon" text is excluded', () {
      expect(
        isPetHotel({
          'sectors': ['pet_shop'],
          'publicSectorData': {
            'petshop': {
              'profileContent': {'bio': 'Pansiyon urunleri satiyoruz'},
            },
          },
        }),
        isFalse,
      );
    });

    test(
      'Pet Shop products and description mentioning hotels are excluded',
      () {
        expect(
          isPetHotel({
            'sectors': ['pet_shop'],
            'category': 'Retail',
            'profile': {
              'categories': ['Hotel Beds'],
              'tags': ['boarding'],
            },
            'publicSectorData': {
              'petshop': {
                'shopTypes': ['Mixed'],
                'categories': ['Beds for hotel stays'],
                'profileContent': {'bio': 'Pansiyon ve otel urunleri'},
              },
            },
          }),
          isFalse,
        );
      },
    );

    test('canonical businesses of every other sector are excluded', () {
      for (final sector in [
        'vet',
        'groomy',
        'pet_shop',
        'pet_taxi',
        'adoption_center',
        'training',
      ]) {
        expect(
          isPetHotel({
            'sectors': [sector],
            'publicSectorData': {
              sector: {'services': <dynamic>[]},
            },
          }),
          isFalse,
          reason: 'a $sector business must not be a Pet Hotel business',
        );
      }
    });
  });

  group('malformed documents fail closed', () {
    final malformed = <String, Map<String, dynamic>>{
      'empty document': <String, dynamic>{},
      'null fields': {'sectors': null, 'publicSectorData': null},
      'numeric sectors': {'sectors': 123},
      'sectors as a map': {
        'sectors': {'groomy': true, 'hotel': true},
      },
      'sectors holding null and numbers': {
        'sectors': [null, 42],
      },
      'sector map stored as a string': {
        'sectorData': 'groomy',
        'publicSectorData': 'hotel',
      },
      'sector map stored as a list': {
        'publicSectorData': ['groomy', 'hotel'],
      },
      'unrelated document': {
        'name': 'Groom & Hotel Supplies',
        'description': 'kuafor, pansiyon, boarding',
      },
    };

    malformed.forEach((label, business) {
      test('$label is excluded from every sector', () {
        for (final sector in BusinessSector.values) {
          expect(
            BusinessSector.belongsToSector(business, sector),
            isFalse,
            reason: '$label must not be a $sector business',
          );
        }
      });
    });

    test('non-string sector-map keys are read safely and excluded', () {
      expect(
        isGroomy({
          'publicSectorData': <dynamic, dynamic>{
            1: {'services': <dynamic>[]},
          },
        }),
        isFalse,
      );
    });

    test('a bare string sectors value stays a supported legacy scalar', () {
      // Pre-existing `hasCanonicalSector` behaviour, pinned here so it stays a
      // deliberate legacy allowance rather than an accident of this change.
      expect(isGroomy({'sectors': 'groomy'}), isTrue);
    });
  });

  group('cross-sector exclusivity', () {
    const sectors = <String>[
      BusinessSector.vet,
      BusinessSector.groomy,
      BusinessSector.petShop,
      BusinessSector.petHotel,
      BusinessSector.petTaxi,
      BusinessSector.adoptionCenter,
      BusinessSector.training,
    ];

    /// One approved business per supported sector. The Pet Shop deliberately
    /// carries the exact production content that used to leak: a "Grooming"
    /// shop type plus hotel-related product text.
    Map<String, Map<String, dynamic>> fixtures() {
      final byBusinessId = <String, Map<String, dynamic>>{};
      for (final sector in sectors) {
        byBusinessId['$sector-business'] = {
          'status': 'approved',
          'sectors': [sector],
          'profile': {'displayName': '$sector business'},
          'publicSectorData': {
            sector: {'services': <dynamic>[]},
          },
        };
      }
      byBusinessId['${BusinessSector.petShop}-business'] = {
        'status': 'approved',
        'sectors': [BusinessSector.petShop],
        'profile': {'displayName': 'Pharos'},
        'publicSectorData': {
          'petshop': {
            'shopName': 'Pharos',
            'shopTypes': ['Pet Food', 'Grooming'],
            'categories': ['Beds for hotel stays', 'Boarding Accessories'],
            'brands': 'GroomPro',
            'profileContent': {'bio': 'Kuafor ve pansiyon urunleri'},
          },
        },
      };
      return byBusinessId;
    }

    List<String> select(String sector) {
      final entries = fixtures().entries
          .where((entry) => BusinessSector.belongsToSector(entry.value, sector))
          .map((entry) => entry.key)
          .toList();
      return entries;
    }

    test('Groomy membership selects only the Groomy fixture', () {
      expect(select(BusinessSector.groomy), [
        '${BusinessSector.groomy}-business',
      ]);
    });

    test('Pet Hotel membership selects only the Pet Hotel fixture', () {
      expect(select(BusinessSector.petHotel), [
        '${BusinessSector.petHotel}-business',
      ]);
    });

    test('every sector selects exactly its own fixture', () {
      for (final sector in sectors) {
        expect(select(sector), [
          '$sector-business',
        ], reason: '$sector must select exactly one business');
      }
    });

    test('the Pet Shop predicate still selects the Pet Shop fixture', () {
      final petShop = fixtures()['${BusinessSector.petShop}-business']!;
      expect(PetShopProfileData.isPetShopBusiness(petShop), isTrue);
    });

    test('nested content cannot produce multi-sector membership', () {
      final petShop = fixtures()['${BusinessSector.petShop}-business']!;
      final matched = sectors
          .where((sector) => BusinessSector.belongsToSector(petShop, sector))
          .toList();
      expect(matched, [BusinessSector.petShop]);
    });
  });
}
