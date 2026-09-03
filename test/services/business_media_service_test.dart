import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/business_media_service.dart';

/// The client never writes canonical media: `businessMedia` is server-owned in
/// firestore.rules, so this service uploads to a permitted Storage path and
/// then asks `finalizeBusinessMedia` to adopt it. These tests pin the payload
/// it sends — object path shape, role, and the concurrency tokens — because
/// that payload is exactly what the server re-validates.
void main() {
  const businessId = 'biz-1';

  String storageUrl(String path) =>
      'https://firebasestorage.googleapis.com/v0/b/demo/o/'
      '${Uri.encodeComponent(path)}?alt=media&token=t';

  Map<String, dynamic> item(String path) => {
    'path': path,
    'url': storageUrl(path),
  };

  ({
    BusinessMediaService service,
    List<Map<String, dynamic>> calls,
    List<String> uploads,
  })
  build({
    Future<void> Function(Map<String, dynamic>)? onFinalize,
    Future<void> Function(String)? onUpload,
    FakeFirebaseFirestore? firestore,
  }) {
    final calls = <Map<String, dynamic>>[];
    final uploads = <String>[];
    final service = BusinessMediaService(
      firestore: firestore ?? FakeFirebaseFirestore(),
      clock: () => DateTime.fromMillisecondsSinceEpoch(1727000000000),
      uploader:
          ({required file, required objectPath, required onProgress}) async {
            uploads.add(objectPath);
            onProgress(0.5);
            if (onUpload != null) await onUpload(objectPath);
            onProgress(1);
          },
      finalizer: (payload) async {
        calls.add(payload);
        if (onFinalize != null) await onFinalize(payload);
        return {'status': 'ok'};
      },
    );
    return (service: service, calls: calls, uploads: uploads);
  }

  group('canonical state parsing', () {
    test('reads logo, cover and gallery from the business document', () {
      final media = BusinessMedia.fromBusinessData({
        'businessMedia': {
          'logo': item('business_gallery/biz-1/logo_1.jpg'),
          'cover': item('business_cover/biz-1/cover_1.jpg'),
          'gallery': [
            item('business_gallery/biz-1/gallery_1.jpg'),
            item('business_gallery/biz-1/gallery_2.jpg'),
          ],
          'revision': 4,
          'generationId': 'gen-1',
        },
      });
      expect(media.logo!.path, 'business_gallery/biz-1/logo_1.jpg');
      expect(media.cover!.path, 'business_cover/biz-1/cover_1.jpg');
      expect(media.gallery.length, 2);
      expect(media.revision, 4);
      expect(media.generationId, 'gen-1');
      expect(media.isEmpty, isFalse);
    });

    test('absent media is an empty, non-crashing state', () {
      for (final data in <Map<String, dynamic>?>[
        null,
        {},
        {'businessMedia': null},
        {'businessMedia': 'nope'},
        {'businessMedia': <dynamic>[]},
        {'businessMedia': 42},
      ]) {
        final media = BusinessMedia.fromBusinessData(data);
        expect(media.isEmpty, isTrue, reason: '$data');
        expect(media.gallery, isEmpty);
        expect(media.revision, 0);
      }
    });

    test('malformed entries are dropped rather than repaired', () {
      final media = BusinessMedia.fromBusinessData({
        'businessMedia': {
          'logo': {'path': 'p'}, // no url
          'cover': {'url': 'u'}, // no path
          'gallery': [
            null,
            'string',
            {'path': '', 'url': 'u'},
            item('business_gallery/biz-1/gallery_1.jpg'),
          ],
          'revision': -5,
        },
      });
      expect(media.logo, isNull);
      expect(media.cover, isNull);
      expect(media.gallery.length, 1);
      expect(media.revision, 0);
    });

    test('duplicate gallery paths are collapsed and the cap is applied', () {
      final entries = List.generate(
        14,
        (i) => item('business_gallery/biz-1/gallery_$i.jpg'),
      )..add(item('business_gallery/biz-1/gallery_0.jpg'));
      final media = BusinessMedia.fromBusinessData({
        'businessMedia': {'gallery': entries},
      });
      expect(media.gallery.length, BusinessMedia.galleryMaxItems);
      expect(
        media.gallery.map((e) => e.path).toSet().length,
        media.gallery.length,
      );
      expect(media.galleryIsFull, isTrue);
    });
  });

  group('object path contract', () {
    test('each role produces its own prefixed, versioned object path', () {
      final s = build().service;
      final at = DateTime.fromMillisecondsSinceEpoch(1727000000000);
      expect(
        s.objectPathFor(
          businessId: businessId,
          role: BusinessMediaRole.logo,
          at: at,
        ),
        'business_gallery/biz-1/logo_1727000000000.jpg',
      );
      expect(
        s.objectPathFor(
          businessId: businessId,
          role: BusinessMediaRole.gallery,
          at: at,
        ),
        'business_gallery/biz-1/gallery_1727000000000.jpg',
      );
      expect(
        s.objectPathFor(
          businessId: businessId,
          role: BusinessMediaRole.cover,
          at: at,
        ),
        'business_cover/biz-1/cover_1727000000000.jpg',
      );
    });

    test('replacement never reuses an object name', () {
      final s = build().service;
      final a = s.objectPathFor(
        businessId: businessId,
        role: BusinessMediaRole.logo,
        at: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final b = s.objectPathFor(
        businessId: businessId,
        role: BusinessMediaRole.logo,
        at: DateTime.fromMillisecondsSinceEpoch(2),
      );
      expect(a, isNot(b));
    });

    test('the path is always scoped to the caller-independent business id', () {
      final s = build().service;
      final path = s.objectPathFor(
        businessId: 'other-biz',
        role: BusinessMediaRole.logo,
      );
      expect(path, startsWith('business_gallery/other-biz/'));
    });
  });

  group('upload payload', () {
    test('sends role, path and both concurrency tokens', () async {
      final harness = build();
      await harness.service.upload(
        businessId: businessId,
        role: BusinessMediaRole.logo,
        file: File('a.jpg'),
        current: const BusinessMedia(revision: 3, generationId: 'gen-1'),
      );
      expect(
        harness.uploads.single,
        'business_gallery/biz-1/logo_1727000000000.jpg',
      );
      final call = harness.calls.single;
      expect(call['role'], 'logo');
      expect(call['action'], 'set');
      expect(call['objectPath'], harness.uploads.single);
      expect(call['expectedRevision'], 3);
      expect(call['expectedGenerationId'], 'gen-1');
      // The client never sends an owner id or a download URL.
      expect(call.containsKey('ownerUid'), isFalse);
      expect(call.containsKey('url'), isFalse);
    });

    test('omits the generation token when the business has none', () async {
      final harness = build();
      await harness.service.upload(
        businessId: businessId,
        role: BusinessMediaRole.cover,
        file: File('a.jpg'),
        current: const BusinessMedia(revision: 0),
      );
      expect(harness.calls.single.containsKey('expectedGenerationId'), isFalse);
    });

    test('reports progress during upload', () async {
      final harness = build();
      final seen = <double>[];
      await harness.service.upload(
        businessId: businessId,
        role: BusinessMediaRole.gallery,
        file: File('a.jpg'),
        current: const BusinessMedia(),
        onProgress: seen.add,
      );
      expect(seen, [0.5, 1]);
    });

    test('a full gallery is refused before anything is uploaded', () async {
      final harness = build();
      final full = BusinessMedia(
        gallery: List.generate(
          BusinessMedia.galleryMaxItems,
          (i) => BusinessMediaItem(
            path: 'business_gallery/biz-1/gallery_$i.jpg',
            url: storageUrl('business_gallery/biz-1/gallery_$i.jpg'),
          ),
        ),
      );
      await expectLater(
        harness.service.upload(
          businessId: businessId,
          role: BusinessMediaRole.gallery,
          file: File('a.jpg'),
          current: full,
        ),
        throwsA(isA<BusinessMediaException>()),
      );
      expect(harness.uploads, isEmpty, reason: 'no wasted upload');
      expect(harness.calls, isEmpty);
    });

    test(
      'a finalization failure surfaces a stable code, not a raw error',
      () async {
        final harness = build(
          onFinalize: (_) async => throw StateError('boom: gs://bucket/secret'),
        );
        await expectLater(
          harness.service.upload(
            businessId: businessId,
            role: BusinessMediaRole.logo,
            file: File('a.jpg'),
            current: const BusinessMedia(),
          ),
          throwsA(
            isA<BusinessMediaException>().having(
              (e) => e.code,
              'code',
              'unavailable',
            ),
          ),
        );
      },
    );
  });

  group('removal and reorder payloads', () {
    test('removal sends the canonical path, never a URL', () async {
      final harness = build();
      const path = 'business_gallery/biz-1/gallery_1.jpg';
      await harness.service.remove(
        businessId: businessId,
        role: BusinessMediaRole.gallery,
        current: const BusinessMedia(revision: 2, generationId: 'gen-1'),
        path: path,
      );
      final call = harness.calls.single;
      expect(call['action'], 'remove');
      expect(call['objectPath'], path);
      expect(call['expectedRevision'], 2);
      expect(
        call.values.whereType<String>().any((v) => v.startsWith('https://')),
        isFalse,
      );
      expect(harness.uploads, isEmpty);
    });

    test('single-image removal needs no path', () async {
      final harness = build();
      await harness.service.remove(
        businessId: businessId,
        role: BusinessMediaRole.logo,
        current: const BusinessMedia(revision: 1),
      );
      expect(harness.calls.single.containsKey('objectPath'), isFalse);
    });

    test('reorder sends the full ordered path list', () async {
      final harness = build();
      await harness.service.reorderGallery(
        businessId: businessId,
        current: const BusinessMedia(revision: 5, generationId: 'gen-1'),
        orderedPaths: const ['b', 'a'],
      );
      final call = harness.calls.single;
      expect(call['action'], 'reorder');
      expect(call['order'], ['b', 'a']);
      expect(call['expectedRevision'], 5);
    });
  });

  group('authoritative state stream', () {
    test('watch emits the canonical state written by the server', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('businesses').doc(businessId).set({
        'ownerUid': 'owner-1',
        'businessMedia': {
          'logo': item('business_gallery/biz-1/logo_1.jpg'),
          'gallery': [],
          'revision': 1,
        },
      });
      final service = BusinessMediaService(
        firestore: firestore,
        uploader:
            ({
              required file,
              required objectPath,
              required onProgress,
            }) async {},
        finalizer: (_) async => {},
      );
      final media = await service.watch(businessId).first;
      expect(media.logo!.path, 'business_gallery/biz-1/logo_1.jpg');
      expect(media.revision, 1);

      final loaded = await service.load(businessId);
      expect(loaded.logo, media.logo);
    });

    test('a business with no media streams an empty state', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('businesses').doc(businessId).set({
        'ownerUid': 'owner-1',
      });
      final service = BusinessMediaService(
        firestore: firestore,
        uploader:
            ({
              required file,
              required objectPath,
              required onProgress,
            }) async {},
        finalizer: (_) async => {},
      );
      expect((await service.watch(businessId).first).isEmpty, isTrue);
    });
  });
}
