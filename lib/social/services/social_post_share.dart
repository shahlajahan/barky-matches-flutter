class SocialPostShare {
  static const canonicalHost = 'app.petsupo.com';

  static String canonicalUrl(String postId) =>
      'https://$canonicalHost/post/${Uri.encodeComponent(postId)}';

  static String? postIdFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final isSupportedHost =
        uri.host.isEmpty ||
        uri.host == canonicalHost ||
        uri.host == 'petsupo.com' ||
        uri.host == 'www.petsupo.com' ||
        uri.host == 'barkymatches-new.web.app' ||
        uri.host == 'barkymatches-new.firebaseapp.com' ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1';

    if (!isSupportedHost || segments.length != 2 || segments.first != 'post') {
      return null;
    }

    final postId = Uri.decodeComponent(segments.last).trim();
    return postId.isEmpty ? null : postId;
  }

  static String? postIdFromDeepLink(Uri uri) {
    if (uri.scheme == 'https') return postIdFromUri(uri);

    if (uri.scheme == 'barkymatches' && uri.host == 'post') {
      final postId = uri.pathSegments.isEmpty
          ? ''
          : Uri.decodeComponent(uri.pathSegments.first).trim();
      return postId.isEmpty ? null : postId;
    }

    return null;
  }

  static bool isPubliclyShareable(Map<String, dynamic> data) {
    final visibility = (data['visibility'] ?? 'public').toString();
    final moderationStatus = (data['moderationStatus'] ?? 'active').toString();
    final isHidden = data['isHidden'] == true;
    final isDeleted =
        data['deleted'] == true ||
        data['deletedAt'] != null ||
        moderationStatus == 'deleted';
    final isPublished = data['published'] == null || data['published'] == true;

    return visibility == 'public' &&
        isPublished &&
        !isDeleted &&
        !isHidden &&
        moderationStatus == 'active';
  }
}
