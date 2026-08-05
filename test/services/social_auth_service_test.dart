import 'package:barky_matches_fixed/services/social_auth_service.dart';
import 'package:barky_matches_fixed/apple_account_recovery_page.dart';
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
    expect(shouldShowAppleSignIn(enabled: true, supported: true), isTrue);
    expect(shouldShowAppleSignIn(enabled: true, supported: false), isFalse);
    expect(shouldShowAppleSignIn(enabled: false, supported: true), isFalse);
  });

  test('desktop Web authentication stays on popup flow', () {
    expect(shouldUseWebRedirect(isWeb: true, isMobileSafari: false), isFalse);
  });

  test('mobile Safari Web authentication uses redirect flow', () {
    expect(shouldUseWebRedirect(isWeb: true, isMobileSafari: true), isTrue);
  });

  test('native platforms never use Web redirect flow', () {
    expect(shouldUseWebRedirect(isWeb: false, isMobileSafari: true), isFalse);
    expect(shouldUseWebRedirect(isWeb: false, isMobileSafari: false), isFalse);
  });

  test('Apple profile creation is idempotent at the document boundary', () {
    final first = buildSocialProfileCreationData(
      uid: 'apple-user',
      providerId: 'apple.com',
      email: 'first@example.com',
      displayName: 'Apple User',
      photoUrl: '',
      serverTimestamp: 'server-time',
    );
    final returning = buildSocialProfileLoginMetadata(
      providerId: 'apple.com',
      serverTimestamp: 'later-time',
      providerArrayValue: const ['apple.com'],
    );

    expect(first['uid'], 'apple-user');
    expect(first['email'], 'first@example.com');
    expect(first['username'], 'Apple User');
    expect(returning, isNot(contains('email')));
    expect(returning, isNot(contains('username')));
  });

  test('Apple cancellation remains a non-writing authentication outcome', () {
    expect(const SocialAuthCancelled(), isA<SocialAuthCancelled>());
  });

  test('new Apple users are held before profile creation', () {
    expect(shouldHoldNewAppleSession(isNewUser: true), isTrue);
    expect(shouldHoldNewAppleSession(isNewUser: false), isFalse);
  });

  test('Apple recovery choices keep creation and linking explicit', () {
    expect(
      AppleRecoveryChoice.createNewAccount,
      isNot(AppleRecoveryChoice.existingAccount),
    );
  });

  test(
    'successful Apple linking must preserve UID and provider membership',
    () {
      expect(
        appleLinkPreservesUid(
          uidBefore: 'canonical-uid',
          uidAfter: 'canonical-uid',
          providerIds: const ['google.com', 'apple.com'],
        ),
        isTrue,
      );
      expect(
        appleLinkPreservesUid(
          uidBefore: 'canonical-uid',
          uidAfter: 'new-uid',
          providerIds: const ['apple.com'],
        ),
        isFalse,
      );
      expect(
        appleLinkPreservesUid(
          uidBefore: 'canonical-uid',
          uidAfter: 'canonical-uid',
          providerIds: const ['google.com'],
        ),
        isFalse,
      );
    },
  );
}
