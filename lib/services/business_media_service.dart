import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'image_upload_service.dart';

/// Canonical business media (logo / cover / gallery).
///
/// The authoritative state lives in `businesses/{businessId}.businessMedia`,
/// which `firestore.rules` marks server-owned: no Firebase client SDK actor —
/// owner or admin — can write it. The only writer is the `finalizeBusinessMedia`
/// callable, which re-derives ownership from `auth.uid`, proves the uploaded
/// object exists in this business's own Storage namespace with a permitted
/// content type and size, and only then commits the transition.
///
/// So this client never writes media state. It uploads an image to a path the
/// deployed owner-bound Storage Rules already permit, then asks the server to
/// adopt it. A failed finalization therefore leaves the previous image intact.
enum BusinessMediaRole { logo, cover, gallery }

extension BusinessMediaRoleName on BusinessMediaRole {
  String get wireName => switch (this) {
    BusinessMediaRole.logo => 'logo',
    BusinessMediaRole.cover => 'cover',
    BusinessMediaRole.gallery => 'gallery',
  };
}

/// One stored image. [path] is the canonical Storage object path and is the
/// only value ever used as deletion authority; [url] is a download URL the
/// server derived from that verified object.
class BusinessMediaItem {
  const BusinessMediaItem({required this.path, required this.url});

  final String path;
  final String url;

  static BusinessMediaItem? fromMap(dynamic value) {
    if (value is! Map) return null;
    final path = value['path'];
    final url = value['url'];
    if (path is! String || path.trim().isEmpty) return null;
    if (url is! String || url.trim().isEmpty) return null;
    return BusinessMediaItem(path: path, url: url);
  }

  @override
  bool operator ==(Object other) =>
      other is BusinessMediaItem && other.path == path && other.url == url;

  @override
  int get hashCode => Object.hash(path, url);
}

/// The authoritative media state as stored on the business document.
class BusinessMedia {
  const BusinessMedia({
    this.logo,
    this.cover,
    this.gallery = const [],
    this.revision = 0,
    this.generationId,
  });

  static const int galleryMaxItems = 10;

  final BusinessMediaItem? logo;
  final BusinessMediaItem? cover;
  final List<BusinessMediaItem> gallery;
  final int revision;
  final String? generationId;

  bool get isEmpty => logo == null && cover == null && gallery.isEmpty;
  bool get galleryIsFull => gallery.length >= galleryMaxItems;

  /// Reads whichever representation is available.
  ///
  /// `businesses/{id}` stores `businessMedia`; the public projection
  /// republishes the same shape (minus `revision`/`generationId`) under the
  /// identical key in `businesses_public/{id}`. Anything malformed is dropped
  /// rather than repaired, so a hand-written or partially-written value can
  /// never crash a caller or reach the UI as a broken reference.
  static BusinessMedia fromBusinessData(Map<String, dynamic>? data) {
    final raw = data == null ? null : data['businessMedia'];
    if (raw is! Map) return const BusinessMedia();

    final gallery = <BusinessMediaItem>[];
    final seen = <String>{};
    final rawGallery = raw['gallery'];
    if (rawGallery is List) {
      for (final entry in rawGallery) {
        final item = BusinessMediaItem.fromMap(entry);
        if (item == null || !seen.add(item.path)) continue;
        gallery.add(item);
        if (gallery.length >= galleryMaxItems) break;
      }
    }

    final revision = raw['revision'];
    final generationId = raw['generationId'];
    return BusinessMedia(
      logo: BusinessMediaItem.fromMap(raw['logo']),
      cover: BusinessMediaItem.fromMap(raw['cover']),
      gallery: gallery,
      revision: revision is int && revision >= 0 ? revision : 0,
      generationId: generationId is String && generationId.trim().isNotEmpty
          ? generationId
          : null,
    );
  }

  BusinessMediaItem? itemFor(BusinessMediaRole role) => switch (role) {
    BusinessMediaRole.logo => logo,
    BusinessMediaRole.cover => cover,
    BusinessMediaRole.gallery => null,
  };
}

/// Raised for an operation the user should see a specific message about.
class BusinessMediaException implements Exception {
  const BusinessMediaException(this.code);

  /// A stable machine code (`unauthenticated`, `permission-denied`,
  /// `failed-precondition`, `invalid-argument`, `not-found`, `unavailable`,
  /// `already-exists`, `internal`). Callers map it to a localized string; the
  /// raw server message, object path and bucket are never surfaced to users.
  final String code;

  @override
  String toString() => 'BusinessMediaException($code)';
}

/// Uploads [file] to [objectPath] and returns when the object exists.
typedef BusinessMediaUploader =
    Future<void> Function({
      required File file,
      required String objectPath,
      required void Function(double progress) onProgress,
    });

/// Invokes the `finalizeBusinessMedia` callable with [payload].
typedef BusinessMediaFinalizer =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

class BusinessMediaService {
  BusinessMediaService({
    FirebaseFirestore? firestore,
    BusinessMediaUploader? uploader,
    BusinessMediaFinalizer? finalizer,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _uploader = uploader ?? _defaultUploader,
       _finalizer = finalizer ?? _defaultFinalizer,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final BusinessMediaUploader _uploader;
  final BusinessMediaFinalizer _finalizer;
  final DateTime Function() _clock;

  static Future<void> _defaultUploader({
    required File file,
    required String objectPath,
    required void Function(double progress) onProgress,
  }) async {
    await ImageUploadService.uploadBusinessMediaImage(
      file: file,
      objectPath: objectPath,
      onProgress: onProgress,
    );
  }

  static Future<Map<String, dynamic>> _defaultFinalizer(
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('finalizeBusinessMedia');
    final result = await callable.call<dynamic>(payload);
    final data = result.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Authoritative state, streamed from the canonical document.
  ///
  /// Seller Settings renders from this rather than from local state, so
  /// "saved" is only ever shown once the server-written value is observed.
  Stream<BusinessMedia> watch(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .map((snapshot) => BusinessMedia.fromBusinessData(snapshot.data()));
  }

  Future<BusinessMedia> load(String businessId) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .get();
    return BusinessMedia.fromBusinessData(snapshot.data());
  }

  /// The exact object path for [role], matching the server's role contract.
  ///
  /// The millisecond stamp makes every replacement a distinct object, so no
  /// device or CDN can serve a stale image from a previously cached URL, and
  /// the mandatory role prefix is what stops a gallery object being finalized
  /// as the logo.
  String objectPathFor({
    required String businessId,
    required BusinessMediaRole role,
    DateTime? at,
  }) {
    final stamp = (at ?? _clock()).millisecondsSinceEpoch;
    return switch (role) {
      BusinessMediaRole.logo => 'business_gallery/$businessId/logo_$stamp.jpg',
      BusinessMediaRole.gallery =>
        'business_gallery/$businessId/gallery_$stamp.jpg',
      BusinessMediaRole.cover => 'business_cover/$businessId/cover_$stamp.jpg',
    };
  }

  /// Uploads [file] and asks the server to adopt it as [role].
  ///
  /// [expectedRevision] and [expectedGenerationId] are concurrency tokens read
  /// from the state the user was actually looking at: if another device changed
  /// the media, or the business was recreated under a new incarnation, the
  /// server rejects the transition rather than overwriting.
  Future<void> upload({
    required String businessId,
    required BusinessMediaRole role,
    required File file,
    required BusinessMedia current,
    void Function(double progress)? onProgress,
  }) async {
    if (role == BusinessMediaRole.gallery && current.galleryIsFull) {
      throw const BusinessMediaException('failed-precondition');
    }
    final objectPath = objectPathFor(businessId: businessId, role: role);
    await _guard(() async {
      await _uploader(
        file: file,
        objectPath: objectPath,
        onProgress: onProgress ?? (_) {},
      );
      await _finalizer({
        'businessId': businessId,
        'role': role.wireName,
        'action': 'set',
        'objectPath': objectPath,
        'expectedRevision': current.revision,
        if (current.generationId != null)
          'expectedGenerationId': current.generationId,
      });
    });
  }

  /// Removes [role]'s image. For the gallery, [path] selects which one.
  ///
  /// The canonical path is passed, never a download URL: deletion authority
  /// belongs to the stored object path alone, which the server re-checks
  /// against this business's namespace before deleting anything.
  Future<void> remove({
    required String businessId,
    required BusinessMediaRole role,
    required BusinessMedia current,
    String? path,
  }) async {
    final payload = <String, dynamic>{
      'businessId': businessId,
      'role': role.wireName,
      'action': 'remove',
      'expectedRevision': current.revision,
    };
    if (path != null) payload['objectPath'] = path;
    if (current.generationId != null) {
      payload['expectedGenerationId'] = current.generationId;
    }
    await _guard(() => _finalizer(payload));
  }

  Future<void> reorderGallery({
    required String businessId,
    required BusinessMedia current,
    required List<String> orderedPaths,
  }) async {
    await _guard(
      () => _finalizer({
        'businessId': businessId,
        'role': 'gallery',
        'action': 'reorder',
        'order': orderedPaths,
        'expectedRevision': current.revision,
        if (current.generationId != null)
          'expectedGenerationId': current.generationId,
      }),
    );
  }

  /// Normalizes every failure into a stable code, so the UI never renders a
  /// raw exception, Storage path, bucket name or identifier.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on BusinessMediaException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw BusinessMediaException(error.code);
    } on FirebaseException catch (error) {
      throw BusinessMediaException(
        error.code.isEmpty ? 'unavailable' : error.code,
      );
    } catch (_) {
      throw const BusinessMediaException('unavailable');
    }
  }
}
