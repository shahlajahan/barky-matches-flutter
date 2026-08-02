import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/social/services/social_post_share.dart';

Map<String, dynamic> publicPost() => {
  'visibility': 'public',
  'published': true,
  'moderationStatus': 'active',
  'isHidden': false,
};

void main() {
  test('canonical share URL uses the production app host', () {
    expect(
      SocialPostShare.canonicalUrl('post/with space'),
      'https://app.petsupo.com/post/post%2Fwith%20space',
    );
  });

  test('valid public post is shareable', () {
    expect(SocialPostShare.isPubliclyShareable(publicPost()), isTrue);
  });

  test('private, deleted, and hidden posts are unavailable to sharing', () {
    final privatePost = publicPost()..['visibility'] = 'private';
    final deletedPost = publicPost()..['deleted'] = true;
    final hiddenPost = publicPost()..['isHidden'] = true;

    expect(SocialPostShare.isPubliclyShareable(privatePost), isFalse);
    expect(SocialPostShare.isPubliclyShareable(deletedPost), isFalse);
    expect(SocialPostShare.isPubliclyShareable(hiddenPost), isFalse);
  });

  test('inactive and unpublished posts are unavailable to sharing', () {
    final unpublishedPost = publicPost()..['published'] = false;
    final moderatedPost = publicPost()..['moderationStatus'] = 'flagged';

    expect(SocialPostShare.isPubliclyShareable(unpublishedPost), isFalse);
    expect(SocialPostShare.isPubliclyShareable(moderatedPost), isFalse);
  });

  test('valid and invalid web post routes are parsed safely', () {
    expect(
      SocialPostShare.postIdFromUri(
        Uri.parse('https://app.petsupo.com/post/post-123'),
      ),
      'post-123',
    );
    expect(
      SocialPostShare.postIdFromUri(
        Uri.parse('https://app.petsupo.com/post/missing/segment'),
      ),
      isNull,
    );
    expect(
      SocialPostShare.postIdFromUri(
        Uri.parse('https://app.petsupo.com/profile/user-123'),
      ),
      isNull,
    );
  });

  test('legacy host and native post links remain parseable', () {
    expect(
      SocialPostShare.postIdFromUri(
        Uri.parse('https://petsupo.com/post/legacy-123'),
      ),
      'legacy-123',
    );
    expect(
      SocialPostShare.postIdFromDeepLink(
        Uri.parse('barkymatches://post/native-123'),
      ),
      'native-123',
    );
  });
}
