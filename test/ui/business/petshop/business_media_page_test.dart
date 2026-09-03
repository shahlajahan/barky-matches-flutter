import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/business_media_service.dart';
import 'package:barky_matches_fixed/ui/business/petshop/business_media_page.dart';

/// Seller Settings → Business Media.
///
/// The page renders the authoritative canonical state only, so these tests
/// drive it through a fake "server": the finalizer writes `businessMedia` into
/// a FakeFirebaseFirestore exactly as the callable would, and the page's own
/// stream is what makes the change appear. A finalizer that throws therefore
/// models a real failed finalization — and the previous image must survive.
void main() {
  const businessId = 'biz-1';

  String urlFor(String path) =>
      'https://firebasestorage.googleapis.com/v0/b/demo/o/'
      '${Uri.encodeComponent(path)}?alt=media&token=t';

  Map<String, dynamic> entry(String path) => {
    'path': path,
    'url': urlFor(path),
  };

  String logoPath([int i = 1]) => 'business_gallery/biz-1/logo_$i.jpg';
  String coverPath([int i = 1]) => 'business_cover/biz-1/cover_$i.jpg';
  String galleryPath([int i = 1]) => 'business_gallery/biz-1/gallery_$i.jpg';

  /// Stands in for the platform picker; always "picks" the same file.
  late _FakePicker picker;

  Future<void> seed(
    FakeFirebaseFirestore db, {
    Map<String, dynamic>? media,
  }) async {
    final doc = <String, dynamic>{
      'ownerUid': 'owner-1',
      'status': 'approved',
      'sectors': ['petshop'],
    };
    if (media != null) doc['businessMedia'] = media;
    await db.collection('businesses').doc(businessId).set(doc);
  }

  /// Applies the mutation the real callable would apply, so the page observes
  /// authoritative state rather than optimistic local state.
  Future<void> applyAsServer(
    FakeFirebaseFirestore db,
    Map<String, dynamic> payload,
  ) async {
    final ref = db.collection('businesses').doc(businessId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final media = Map<String, dynamic>.from(
      (data['businessMedia'] as Map?) ??
          {'gallery': <dynamic>[], 'revision': 0},
    );
    final gallery = List<dynamic>.from((media['gallery'] as List?) ?? []);
    final role = payload['role'] as String;
    final action = payload['action'] as String;

    if (action == 'set' && role == 'gallery') {
      gallery.add(entry(payload['objectPath'] as String));
    } else if (action == 'set') {
      media[role] = entry(payload['objectPath'] as String);
    } else if (action == 'remove' && role == 'gallery') {
      gallery.removeWhere((e) => (e as Map)['path'] == payload['objectPath']);
    } else if (action == 'remove') {
      media[role] = null;
    } else if (action == 'reorder') {
      final order = List<String>.from(payload['order'] as List);
      gallery.sort(
        (a, b) => order
            .indexOf((a as Map)['path'] as String)
            .compareTo(order.indexOf((b as Map)['path'] as String)),
      );
    }
    media['gallery'] = gallery;
    media['revision'] = ((media['revision'] as int?) ?? 0) + 1;
    await ref.set({'businessMedia': media}, SetOptions(merge: true));
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeFirebaseFirestore db,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? finalizer,
    List<String>? uploads,
    void Function(void Function(double))? onUploadProgress,
    Locale locale = const Locale('en'),
  }) async {
    final service = BusinessMediaService(
      firestore: db,
      clock: () => DateTime.fromMillisecondsSinceEpoch(1727000000000),
      uploader:
          ({required file, required objectPath, required onProgress}) async {
            uploads?.add(objectPath);
            onProgress(0.4);
            if (onUploadProgress != null) onUploadProgress(onProgress);
          },
      finalizer:
          finalizer ??
          (payload) async {
            await applyAsServer(db, payload);
            return {'status': 'ok'};
          },
    );
    // The page is a tall ListView; the default 800x600 test viewport would
    // leave the gallery section unbuilt and its controls untappable.
    await tester.binding.setSurfaceSize(const Size(1000, 4200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BusinessMediaPage(
          // A fresh key forces a new State on every pump: the page resolves
          // its service in a `late final`, so reusing State would silently
          // keep a previous test's service.
          key: UniqueKey(),
          businessId: businessId,
          service: service,
          picker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    picker = _FakePicker();
  });

  // ── 3 / 4. authoritative load and empty placeholders ─────────────────────

  testWidgets('4. empty state shows a placeholder for every role', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(db);
    await pumpPage(tester, db: db);

    expect(find.text('No logo yet'), findsOneWidget);
    expect(find.text('No cover image yet'), findsOneWidget);
    expect(find.text('No gallery photos yet'), findsOneWidget);
    expect(find.text('Add Logo'), findsOneWidget);
    expect(find.text('Add Cover'), findsOneWidget);
    expect(find.text('Add Photos'), findsOneWidget);
    // Nothing to remove when nothing is set.
    expect(find.text('Remove Logo'), findsNothing);
    expect(find.text('Remove Cover'), findsNothing);
    expect(find.text('0 of 10 photos'), findsOneWidget);
  });

  testWidgets('3. the page loads canonical logo, cover and gallery', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {
        'logo': entry(logoPath()),
        'cover': entry(coverPath()),
        'gallery': [entry(galleryPath(1)), entry(galleryPath(2))],
        'revision': 3,
      },
    );
    await pumpPage(tester, db: db);

    expect(find.text('No logo yet'), findsNothing);
    expect(find.text('Change Logo'), findsOneWidget);
    expect(find.text('Change Cover'), findsOneWidget);
    expect(find.text('Remove Logo'), findsOneWidget);
    expect(find.text('Remove Cover'), findsOneWidget);
    expect(find.text('2 of 10 photos'), findsOneWidget);
    // Every canonical URL is actually rendered.
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url)
        .toSet();
    expect(urls, containsAll([urlFor(logoPath()), urlFor(coverPath())]));
  });

  // ── 5-10. add / replace / remove for logo and cover ──────────────────────

  testWidgets('5+8. adding a logo and a cover uploads to the role path', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final uploads = <String>[];
    await seed(db);
    await pumpPage(tester, db: db, uploads: uploads);

    await tester.tap(find.text('Add Logo'));
    await tester.pumpAndSettle();
    expect(uploads.single, 'business_gallery/biz-1/logo_1727000000000.jpg');
    expect(find.text('Change Logo'), findsOneWidget);
    expect(find.text('No logo yet'), findsNothing);

    await tester.tap(find.text('Add Cover'));
    await tester.pumpAndSettle();
    expect(uploads.last, 'business_cover/biz-1/cover_1727000000000.jpg');
    expect(find.text('Change Cover'), findsOneWidget);
  });

  testWidgets(
    '6+9. replacing swaps the canonical image without deleting first',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await seed(
        db,
        media: {'logo': entry(logoPath(1)), 'gallery': [], 'revision': 1},
      );
      await pumpPage(tester, db: db);

      expect(find.text('Change Logo'), findsOneWidget);
      await tester.tap(find.text('Change Logo'));
      await tester.pumpAndSettle();

      final stored = (await db.collection('businesses').doc(businessId).get())
          .data()!;
      final media = stored['businessMedia'] as Map;
      expect((media['logo'] as Map)['path'], contains('logo_1727000000000'));
      expect(media['revision'], 2);
    },
  );

  testWidgets('7+10. removal asks for confirmation and clears the reference', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {'logo': entry(logoPath()), 'gallery': [], 'revision': 1},
    );
    await pumpPage(tester, db: db);

    await tester.tap(find.text('Remove Logo'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this image?'), findsOneWidget);

    // Cancelling changes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Change Logo'), findsOneWidget);

    await tester.tap(find.text('Remove Logo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No logo yet'), findsOneWidget);
    expect(find.text('Add Logo'), findsOneWidget);
  });

  // ── 11-15. gallery ───────────────────────────────────────────────────────

  testWidgets('11. adding a gallery photo appends it', (tester) async {
    final db = FakeFirebaseFirestore();
    final uploads = <String>[];
    await seed(db);
    await pumpPage(tester, db: db, uploads: uploads);

    await tester.tap(find.text('Add Photos'));
    await tester.pumpAndSettle();

    expect(uploads.single, 'business_gallery/biz-1/gallery_1727000000000.jpg');
    expect(find.text('1 of 10 photos'), findsOneWidget);
    expect(find.text('No gallery photos yet'), findsNothing);
  });

  testWidgets('12. removing a gallery photo removes only that one', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {
        'gallery': [entry(galleryPath(1)), entry(galleryPath(2))],
        'revision': 2,
      },
    );
    await pumpPage(tester, db: db);
    expect(find.text('2 of 10 photos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 10 photos'), findsOneWidget);
    final media =
        (await db.collection('businesses').doc(businessId).get())
                .data()!['businessMedia']
            as Map;
    expect((media['gallery'] as List).length, 1);
    expect(((media['gallery'] as List).single as Map)['path'], galleryPath(2));
  });

  testWidgets('13. a full gallery blocks adding and explains why', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final uploads = <String>[];
    await seed(
      db,
      media: {
        'gallery': List.generate(10, (i) => entry(galleryPath(i))),
        'revision': 10,
      },
    );
    await pumpPage(tester, db: db, uploads: uploads);

    expect(find.text('10 of 10 photos'), findsOneWidget);
    expect(
      find.text('Your gallery is full. Remove a photo to add another.'),
      findsOneWidget,
    );
    // Behavioural rather than type-based: ElevatedButton.icon returns a
    // private subclass, which find.byType (exact runtimeType) never matches.
    await tester.tap(find.text('Add Photos'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(uploads, isEmpty, reason: 'a full gallery must not upload');
    expect(find.text('10 of 10 photos'), findsOneWidget);
  });

  testWidgets('15. reorder sends the new order and re-renders it', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final payloads = <Map<String, dynamic>>[];
    await seed(
      db,
      media: {
        'gallery': [entry(galleryPath(1)), entry(galleryPath(2))],
        'revision': 2,
      },
    );
    await pumpPage(
      tester,
      db: db,
      finalizer: (payload) async {
        payloads.add(payload);
        await applyAsServer(db, payload);
        return {'status': 'ok'};
      },
    );

    // ReorderableListView installs *delayed* drag handles on this platform,
    // and simulating that gesture is flaky; invoking the exact callback the
    // framework invokes exercises the same _reorder -> service -> server path.
    expect(find.byKey(ValueKey(galleryPath(1))), findsOneWidget);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(0, 2);
    await tester.pumpAndSettle();

    expect(payloads.length, 1, reason: 'exactly one reorder was submitted');
    expect(payloads.single['action'], 'reorder');
    expect(payloads.single['order'], [galleryPath(2), galleryPath(1)]);
    final media =
        (await db.collection('businesses').doc(businessId).get())
                .data()!['businessMedia']
            as Map;
    expect((media['gallery'] as List).map((e) => (e as Map)['path']).toList(), [
      galleryPath(2),
      galleryPath(1),
    ]);
  });

  // ── 16-20. progress, errors, retry, double submit, stale state ───────────

  testWidgets('16. upload progress is shown while an operation runs', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(db);
    final gate = Completer<void>();
    await pumpPage(
      tester,
      db: db,
      finalizer: (payload) async {
        await gate.future;
        await applyAsServer(db, payload);
        return {'status': 'ok'};
      },
    );

    await tester.tap(find.text('Add Logo'));
    await tester.pump();
    expect(find.text('Uploading…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Uploading…'), findsNothing);
  });

  testWidgets('17. a failure shows a friendly message and offers retry', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(db);
    var attempts = 0;
    await pumpPage(
      tester,
      db: db,
      finalizer: (payload) async {
        attempts += 1;
        if (attempts == 1) {
          throw const BusinessMediaException('unavailable');
        }
        await applyAsServer(db, payload);
        return {'status': 'ok'};
      },
    );

    await tester.tap(find.text('Add Logo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    // No raw exception, path or bucket is ever rendered.
    expect(find.textContaining('business_gallery/'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Change Logo'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('18. a finalization failure leaves the old image visible', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {'logo': entry(logoPath(1)), 'gallery': [], 'revision': 1},
    );
    await pumpPage(
      tester,
      db: db,
      finalizer: (_) async => throw const BusinessMediaException('unavailable'),
    );

    await tester.tap(find.text('Change Logo'));
    await tester.pumpAndSettle();

    // The canonical document is untouched, so the previous logo still renders.
    final media =
        (await db.collection('businesses').doc(businessId).get())
                .data()!['businessMedia']
            as Map;
    expect((media['logo'] as Map)['path'], logoPath(1));
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url);
    expect(urls, contains(urlFor(logoPath(1))));
    expect(find.text('Change Logo'), findsOneWidget);
  });

  testWidgets('19. a double tap cannot start two operations', (tester) async {
    final db = FakeFirebaseFirestore();
    final uploads = <String>[];
    final gate = Completer<void>();
    await seed(db);
    await pumpPage(
      tester,
      db: db,
      uploads: uploads,
      finalizer: (payload) async {
        await gate.future;
        await applyAsServer(db, payload);
        return {'status': 'ok'};
      },
    );

    await tester.tap(find.text('Add Photos'));
    await tester.pump();
    // While busy the control is replaced by the progress row, so a second tap
    // cannot even reach it — and the guard in _run() would reject it anyway.
    expect(find.text('Add Photos'), findsNothing);
    expect(find.text('Uploading…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(uploads.length, 1);
    expect(find.text('1 of 10 photos'), findsOneWidget);
  });

  testWidgets(
    '20. a stale-state rejection is explained, not silently retried',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await seed(
        db,
        media: {'logo': entry(logoPath(1)), 'gallery': [], 'revision': 1},
      );
      await pumpPage(
        tester,
        db: db,
        finalizer: (_) async =>
            throw const BusinessMediaException('failed-precondition'),
      );

      await tester.tap(find.text('Change Logo'));
      await tester.pumpAndSettle();

      expect(
        find.text('This was updated somewhere else. Reload and try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('20b. permission and format failures map to their own messages', (
    tester,
  ) async {
    for (final pair in const [
      ('permission-denied', 'You do not manage this business.'),
      ('unauthenticated', 'Please sign in again.'),
      ('invalid-argument', 'That image format is not supported.'),
    ]) {
      final db = FakeFirebaseFirestore();
      await seed(db);
      await pumpPage(
        tester,
        db: db,
        finalizer: (_) async => throw BusinessMediaException(pair.$1),
      );
      await tester.tap(find.text('Add Logo'));
      await tester.pumpAndSettle();
      expect(find.text(pair.$2), findsOneWidget, reason: pair.$1);
    }
  });

  // ── 25. localization and accessibility ───────────────────────────────────

  testWidgets('25. the page is localized, not hard-coded English', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(db);
    await pumpPage(tester, db: db, locale: const Locale('tr'));

    expect(find.text('İşletme Medyası'), findsOneWidget);
    expect(find.text('Logo Ekle'), findsOneWidget);
    expect(find.text('Kapak Ekle'), findsOneWidget);
    expect(find.text('Fotoğraf Ekle'), findsOneWidget);
    expect(find.text('Henüz logo yok'), findsOneWidget);
    // No English leaked through.
    expect(find.text('Add Logo'), findsNothing);
    expect(find.text('Business Media'), findsNothing);
  });

  testWidgets('25b. every locale renders the section headings', (tester) async {
    for (final pair in const [
      (Locale('fa'), 'رسانه کسب‌وکار'),
      (Locale('ru'), 'Медиа бизнеса'),
      (Locale('en'), 'Business Media'),
    ]) {
      final db = FakeFirebaseFirestore();
      await seed(db);
      await pumpPage(tester, db: db, locale: pair.$1);
      expect(find.text(pair.$2), findsWidgets, reason: '${pair.$1}');
    }
  });

  testWidgets('25c. media regions carry accessible labels', (tester) async {
    final handle = tester.ensureSemantics();
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {'logo': entry(logoPath()), 'gallery': [], 'revision': 1},
    );
    await pumpPage(tester, db: db);

    Finder semanticsLabelled(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );
    expect(
      semanticsLabelled('Logo'),
      findsOneWidget,
      reason: 'the logo region must be announced',
    );
    expect(semanticsLabelled('Cover Image'), findsOneWidget);
    expect(semanticsLabelled('Gallery'), findsNothing);
    handle.dispose();
  });

  testWidgets('broken references fall back instead of throwing', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(
      db,
      media: {'logo': entry(logoPath()), 'gallery': [], 'revision': 1},
    );
    await pumpPage(tester, db: db);
    // Image.network fails in tests; the errorBuilder must render the fallback
    // rather than letting an exception reach the widget tree.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

/// Always returns the same picked file, so tests never touch the platform.
class _FakePicker extends ImagePicker {
  int calls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls += 1;
    return XFile('picked.jpg');
  }
}
