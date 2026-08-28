import 'dart:io';

import 'package:barky_matches_fixed/models/public_marketplace_product.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace P1-A Slice 4.8 Phase A (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.14, §15 items
// 422-434): parsing/contract coverage for the new public models,
// matching the live `projectPublicProduct` output shape exactly (all 29
// fields).
void main() {
  Map<String, dynamic> fullFixture({List<Map<String, dynamic>>? media}) {
    return {
      'businessId': 'business-1',
      'productId': 'business-1_SKU-1',
      'name': 'Dog food',
      'description': 'Premium dry food',
      'category': 'Food > Dry Food',
      'brand': 'Acme',
      'media':
          media ??
          [
            {
              'type': 'image',
              'originalUrl': 'https://example.com/a.jpg',
              'playbackUrl': null,
              'thumbnailUrl': 'https://example.com/a-thumb.jpg',
            },
          ],
      'price': 100.0,
      'salePrice': 80.0,
      'currency': 'TRY',
      'kdvRate': 10.0,
      'taxIncluded': true,
      'stock': 5,
      'shippingMode': 'fixed_price',
      'shippingPayer': 'seller',
      'shippingFee': 20.0,
      'freeShippingThreshold': 200.0,
      'allowFreeShipping': false,
      'allowedCarrierCodes': ['YURTICI', 'ARAS'],
      'originCity': 'Istanbul',
      'maxDeliveryDays': 3,
      'deliveryType': 'cargo',
      'weightKg': 1.5,
      'lengthCm': 10.0,
      'widthCm': 10.0,
      'heightCm': 10.0,
      'fixedDesi': 2.0,
      'businessName': 'Acme Pet Shop',
      'businessLogo': 'https://example.com/logo.png',
    };
  }

  group('PublicProductListItem', () {
    test('parses a fixture matching the live 29-field output exactly', () {
      final item = PublicProductListItem.fromJson(fullFixture());

      expect(item.businessId, 'business-1');
      expect(item.productId, 'business-1_SKU-1');
      expect(item.name, 'Dog food');
      expect(item.description, 'Premium dry food');
      expect(item.category, 'Food > Dry Food');
      expect(item.brand, 'Acme');
      expect(item.media, hasLength(1));
      expect(item.price, 100.0);
      expect(item.salePrice, 80.0);
      expect(item.currency, 'TRY');
      expect(item.kdvRate, 10.0);
      expect(item.taxIncluded, isTrue);
      expect(item.stock, 5);
      expect(item.shippingMode, 'fixed_price');
      expect(item.shippingPayer, 'seller');
      expect(item.shippingFee, 20.0);
      expect(item.freeShippingThreshold, 200.0);
      expect(item.allowFreeShipping, isFalse);
      expect(item.allowedCarrierCodes, ['YURTICI', 'ARAS']);
      expect(item.originCity, 'Istanbul');
      expect(item.maxDeliveryDays, 3);
      expect(item.deliveryType, 'cargo');
      expect(item.weightKg, 1.5);
      expect(item.lengthCm, 10.0);
      expect(item.widthCm, 10.0);
      expect(item.heightCm, 10.0);
      expect(item.fixedDesi, 2.0);
      expect(item.businessName, 'Acme Pet Shop');
      expect(item.businessLogo, 'https://example.com/logo.png');
    });

    test('numeric fields parse as double/int, never Timestamp-shaped', () {
      final item = PublicProductListItem.fromJson(fullFixture());

      expect(item.price, isA<double>());
      expect(item.stock, isA<int>());
      expect(item.maxDeliveryDays, isA<int>());
      expect(item.weightKg, isA<double>());
    });

    test('media renders in exactly the fixture array order', () {
      final item = PublicProductListItem.fromJson(
        fullFixture(
          media: [
            {
              'type': 'image',
              'originalUrl': 'https://example.com/1.jpg',
              'playbackUrl': null,
              'thumbnailUrl': null,
            },
            {
              'type': 'video',
              'originalUrl': null,
              'playbackUrl': 'https://example.com/2.mp4',
              'thumbnailUrl': 'https://example.com/2-thumb.jpg',
            },
          ],
        ),
      );

      expect(item.media[0].originalUrl, 'https://example.com/1.jpg');
      expect(item.media[1].playbackUrl, 'https://example.com/2.mp4');
    });

    test('every optional field parses correctly when null', () {
      final fixture = fullFixture()
        ..['description'] = null
        ..['brand'] = null
        ..['salePrice'] = null
        ..['kdvRate'] = null
        ..['taxIncluded'] = null
        ..['shippingMode'] = null
        ..['shippingPayer'] = null
        ..['shippingFee'] = null
        ..['freeShippingThreshold'] = null
        ..['originCity'] = null
        ..['maxDeliveryDays'] = null
        ..['deliveryType'] = null
        ..['weightKg'] = null
        ..['lengthCm'] = null
        ..['widthCm'] = null
        ..['heightCm'] = null
        ..['fixedDesi'] = null
        ..['businessName'] = null
        ..['businessLogo'] = null;

      final item = PublicProductListItem.fromJson(fixture);

      expect(item.description, isNull);
      expect(item.brand, isNull);
      expect(item.salePrice, isNull);
      expect(item.businessLogo, isNull);
    });

    test('every optional field parses correctly when absent entirely', () {
      final fixture = fullFixture()
        ..remove('description')
        ..remove('brand')
        ..remove('salePrice')
        ..remove('businessName');

      final item = PublicProductListItem.fromJson(fixture);

      expect(item.description, isNull);
      expect(item.brand, isNull);
      expect(item.salePrice, isNull);
      expect(item.businessName, isNull);
    });

    for (final requiredField in [
      'businessId',
      'productId',
      'name',
      'category',
      'price',
      'stock',
      'currency',
      'media',
      'allowFreeShipping',
      'allowedCarrierCodes',
    ]) {
      test('throws when required field "$requiredField" is missing', () {
        final fixture = fullFixture()..remove(requiredField);

        expect(
          () => PublicProductListItem.fromJson(fixture),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('an unknown key is ignored, never an error', () {
      final fixture = fullFixture()..['futureField'] = 'unexpected';

      expect(() => PublicProductListItem.fromJson(fixture), returnsNormally);
    });

    // Failed independent audit correction: §15 item 429 — the ≤1 list-cap
    // is a server-side guarantee only (§0.14); PublicProductListItem's own
    // parser performs no client-side capping/truncation of its own, so a
    // fixture the server would never actually send (2+ entries) must still
    // parse every entry, in order, rather than silently reducing to a
    // single "primary" image.
    test('item 429: a fixture with two or more ordered media entries — a '
        'contract-violating shape the live server would never actually '
        'send, since §0.14\'s ≤1 cap is server-side only — still parses '
        'every entry, in exact order, never silently reduced to the '
        'first image only', () {
      final item = PublicProductListItem.fromJson(
        fullFixture(
          media: [
            {
              'type': 'image',
              'originalUrl': 'https://example.com/1.jpg',
              'playbackUrl': null,
              'thumbnailUrl': null,
            },
            {
              'type': 'video',
              'originalUrl': null,
              'playbackUrl': 'https://example.com/2.mp4',
              'thumbnailUrl': 'https://example.com/2-thumb.jpg',
            },
            {
              'type': 'image',
              'originalUrl': 'https://example.com/3.jpg',
              'playbackUrl': null,
              'thumbnailUrl': 'https://example.com/3-thumb.jpg',
            },
          ],
        ),
      );

      expect(item.media, hasLength(3));
      expect(item.media[0].originalUrl, 'https://example.com/1.jpg');
      expect(item.media[0].playbackUrl, isNull);
      expect(item.media[1].playbackUrl, 'https://example.com/2.mp4');
      expect(item.media[1].originalUrl, isNull);
      expect(item.media[2].thumbnailUrl, 'https://example.com/3-thumb.jpg');
    });

    test('never carries any of the five reserved compliance names, a '
        'decision path, or an evidence/scope/review-event ID', () {
      const forbidden = [
        'complianceEffectiveStatus',
        'complianceValidUntil',
        'evidenceRevision',
        'complianceUpdatedAt',
        'complianceReasonCode',
        'decisionHash',
        'evidenceLinkId',
        'scopeId',
        'reviewEventId',
      ];
      final source = PublicProductListItem;
      // Source-level guard: the class's own field set is fixed by its
      // constructor, so this is a compile-time guarantee already — this
      // test documents the intent explicitly rather than re-deriving it
      // reflectively.
      expect(source, isNotNull);
      for (final name in forbidden) {
        expect(fullFixture().containsKey(name), isFalse, reason: name);
      }
    });
  });

  group('PublicProductDetail', () {
    // Failed independent audit correction: §15 item 423, strengthened —
    // asserts all 29 fields, matching the depth already used for
    // PublicProductListItem's own equivalent test above (previously this
    // test asserted only 4 of the 29 fields).
    test('parses a fixture matching the live 29-field output exactly', () {
      final detail = PublicProductDetail.fromJson(fullFixture());

      expect(detail.businessId, 'business-1');
      expect(detail.productId, 'business-1_SKU-1');
      expect(detail.name, 'Dog food');
      expect(detail.description, 'Premium dry food');
      expect(detail.category, 'Food > Dry Food');
      expect(detail.brand, 'Acme');
      expect(detail.media, hasLength(1));
      expect(detail.price, 100.0);
      expect(detail.salePrice, 80.0);
      expect(detail.currency, 'TRY');
      expect(detail.kdvRate, 10.0);
      expect(detail.taxIncluded, isTrue);
      expect(detail.stock, 5);
      expect(detail.shippingMode, 'fixed_price');
      expect(detail.shippingPayer, 'seller');
      expect(detail.shippingFee, 20.0);
      expect(detail.freeShippingThreshold, 200.0);
      expect(detail.allowFreeShipping, isFalse);
      expect(detail.allowedCarrierCodes, ['YURTICI', 'ARAS']);
      expect(detail.originCity, 'Istanbul');
      expect(detail.maxDeliveryDays, 3);
      expect(detail.deliveryType, 'cargo');
      expect(detail.weightKg, 1.5);
      expect(detail.lengthCm, 10.0);
      expect(detail.widthCm, 10.0);
      expect(detail.heightCm, 10.0);
      expect(detail.fixedDesi, 2.0);
      expect(detail.businessName, 'Acme Pet Shop');
      expect(detail.businessLogo, 'https://example.com/logo.png');
    });

    test('accepts a media array up to 20 entries (the detail cap)', () {
      final media = List.generate(
        20,
        (i) => {
          'type': 'image',
          'originalUrl': 'https://example.com/$i.jpg',
          'playbackUrl': null,
          'thumbnailUrl': null,
        },
      );
      final detail = PublicProductDetail.fromJson(fullFixture(media: media));

      expect(detail.media, hasLength(20));
    });

    // Failed independent audit correction: §15 item 430 — a fixture
    // exceeding the server's own DETAIL_MEDIA_CAP (a contract-violating
    // shape the live server would never actually send, mirrors item 429
    // for the detail model) still parses every entry, in order, with no
    // client-side truncation — proving this Dart parser never conflates
    // the seller-write cap (§0.14, exactly 20, enforced by
    // buildProductWritePayload) with the public read-side historical/
    // detail projection, which performs no capping of its own.
    test('item 430: a fixture containing more than 20 media entries '
        'parses every entry without truncation — exact count and order '
        'preserved, proving the parser performs no cap enforcement of '
        'its own', () {
      final media = List.generate(
        25,
        (i) => {
          'type': 'image',
          'originalUrl': 'https://example.com/$i.jpg',
          'playbackUrl': null,
          'thumbnailUrl': null,
        },
      );
      final detail = PublicProductDetail.fromJson(fullFixture(media: media));

      expect(detail.media, hasLength(25));
      for (var i = 0; i < 25; i++) {
        expect(detail.media[i].originalUrl, 'https://example.com/$i.jpg');
      }
    });

    for (final requiredField in [
      'businessId',
      'productId',
      'name',
      'category',
      'price',
      'stock',
      'currency',
      'media',
      'allowFreeShipping',
      'allowedCarrierCodes',
    ]) {
      test('throws when required field "$requiredField" is missing', () {
        final fixture = fullFixture()..remove(requiredField);

        expect(
          () => PublicProductDetail.fromJson(fixture),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });

  group('PublicProductMedia', () {
    test('tolerates all three URL fields being null identically', () {
      final media = PublicProductMedia.fromJson({
        'type': 'image',
        'originalUrl': null,
        'playbackUrl': null,
        'thumbnailUrl': null,
      });

      expect(media.originalUrl, isNull);
      expect(media.playbackUrl, isNull);
      expect(media.thumbnailUrl, isNull);
    });

    test('tolerates only thumbnailUrl being present', () {
      final media = PublicProductMedia.fromJson({
        'type': 'image',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
      });

      expect(media.originalUrl, isNull);
      expect(media.thumbnailUrl, 'https://example.com/thumb.jpg');
    });
  });

  // Failed independent audit correction: §15 item 434 — a real
  // source-inspection test against public_marketplace_product.dart
  // itself, not merely a fixture-key check (the pre-existing
  // "never carries any of the five reserved compliance names" test,
  // above, only proves this test file's own fixture never includes
  // them — it says nothing about whether the CLASSES themselves would
  // reject/never-expose them if a server response ever did include one).
  group(
    'item 434: source-inspection proof (public_marketplace_product.dart)',
    () {
      late String source;

      setUpAll(() {
        source = File(
          'lib/models/public_marketplace_product.dart',
        ).readAsStringSync();
      });

      const reservedNames = [
        'complianceEffectiveStatus',
        'complianceValidUntil',
        'evidenceRevision',
        'complianceUpdatedAt',
        'complianceReasonCode',
      ];

      test('none of the five reserved names appears anywhere in this file\'s '
          'own source — not as a field declaration, constructor parameter, '
          'fromJson parsing key, or any other class-API member', () {
        for (final name in reservedNames) {
          // A blind substring check is deliberately sufficient and
          // stricter here (unlike add_product_page.dart, this file's own
          // header comment lists the five names too — so first confirm
          // that comment, then confirm zero remaining occurrences once
          // it is excluded, proving no *second*, code-shaped occurrence
          // exists beyond the documented exclusion).
          final occurrences = name.allMatches(source).length;
          final commentOccurrences = name.allMatches(source).where((m) {
            final lineStart = source.lastIndexOf('\n', m.start) + 1;
            final line = source.substring(
              lineStart,
              source.indexOf('\n', m.start).clamp(lineStart, source.length),
            );
            return line.trimLeft().startsWith('//');
          }).length;
          expect(
            occurrences,
            commentOccurrences,
            reason:
                '$name must appear only inside a // comment line (the '
                'explanatory header), never in field/constructor/'
                'fromJson/toJson code',
          );
        }
      });

      test('PublicProductMedia/PublicProductListItem/PublicProductDetail '
          'declare exactly their own frozen field sets — no field named '
          'after any reserved concept (decisionHash/evidenceLinkId/scopeId/'
          'reviewEventId) is declared', () {
        const forbiddenConceptNames = [
          'decisionHash',
          'evidenceLinkId',
          'scopeId',
          'reviewEventId',
          'productComplianceDecisions',
          'productEvidenceLinks',
        ];
        for (final name in forbiddenConceptNames) {
          expect(source, isNot(contains(name)), reason: name);
        }
      });
    },
  );
}
