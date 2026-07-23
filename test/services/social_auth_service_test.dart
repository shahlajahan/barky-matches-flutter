import 'package:barky_matches_fixed/services/social_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first-time social profile uses the existing users schema', () {
    final data = buildSocialProfileCreationData(
      uid: 'firebase-uid',
      providerId: 'google.com',
      email: 'Person@Example.com',
      displayName: 'Pet Owner',
      photoUrl: 'https://example.com/photo.jpg',
      serverTimestamp: 'server-time',
    );

    expect(data['uid'], 'firebase-uid');
    expect(data['username'], 'Pet Owner');
    expect(data['email'], 'person@example.com');
    expect(data['photoUrl'], 'https://example.com/photo.jpg');
    expect(data['profileCompleted'], isFalse);
    expect(data['authProvider'], 'google.com');
    expect(data['createdAt'], 'server-time');
  });

  test('returning-user metadata cannot overwrite profile fields', () {
    final metadata = buildSocialProfileLoginMetadata(
      providerId: 'apple.com',
      serverTimestamp: 'server-time',
      providerArrayValue: const ['apple.com'],
    );

    expect(metadata.keys, {
      'authProvider',
      'authProviders',
      'lastLoginAt',
      'updatedAt',
    });
    expect(metadata, isNot(contains('username')));
    expect(metadata, isNot(contains('city')));
    expect(metadata, isNot(contains('photoUrl')));
    expect(metadata, isNot(contains('role')));
  });

  test('missing required profile fields are detected', () {
    expect(
      socialProfileMissingFields({
        'username': 'Pet Owner',
        'city': '',
        'district': '',
        'termsAccepted': false,
      }),
      ['city', 'district', 'termsAccepted'],
    );
  });

  test('complete returning profile does not require completion', () {
    expect(
      socialProfileMissingFields({
        'username': 'Pet Owner',
        'city': 'Istanbul',
        'district': 'Kadikoy',
        'termsAccepted': true,
      }),
      isEmpty,
    );
  });

  test('social cancellation has a dedicated non-error result type', () {
    expect(const SocialAuthCancelled(), isA<SocialAuthCancelled>());
  });

  test('Apple button visibility is limited to supported platforms', () {
    expect(
      supportsAppleOnPlatform(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      supportsAppleOnPlatform(isWeb: true, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      supportsAppleOnPlatform(isWeb: false, platform: TargetPlatform.android),
      isFalse,
    );
  });
}
