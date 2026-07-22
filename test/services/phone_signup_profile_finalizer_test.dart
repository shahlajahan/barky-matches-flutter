import 'package:barky_matches_fixed/services/phone_signup_profile_finalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const input = PhoneSignupProfileInput(
    username: 'User B',
    email: '',
    phone: '+905551111111',
    city: 'Istanbul',
    district: 'Kadikoy',
    receiveNews: true,
  );

  test('signup data is finalized under User B and never User A', () async {
    String? writtenUid;
    Map<String, dynamic>? writtenData;

    await finalizePhoneSignupBeforeInitialization(
      authenticatedUid: 'user-b',
      input: input,
      finalizeProfile: (uid, profile) async {
        writtenUid = uid;
        writtenData = profile.buildMergeData(
          authenticatedUid: uid,
          serverTimestamp: 'server-time',
          existingProfileHasCreatedAt: false,
        );
      },
      initializeUserB: () async {},
    );

    expect(writtenUid, 'user-b');
    expect(writtenUid, isNot('user-a'));
    expect(writtenData, containsPair('uid', 'user-b'));
    expect(writtenData, containsPair('username', 'User B'));
    expect(writtenData, containsPair('phone', '+905551111111'));
    expect(writtenData, containsPair('receiveNews', true));
    expect(writtenData, containsPair('createdAt', 'server-time'));
  });

  test('empty optional fields do not erase existing profile values', () {
    const sparseInput = PhoneSignupProfileInput(
      username: 'Updated Name',
      email: '',
      phone: '+905551111111',
      city: '',
      district: '',
      receiveNews: false,
    );

    final data = sparseInput.buildMergeData(
      authenticatedUid: 'user-b',
      serverTimestamp: 'server-time',
      existingProfileHasCreatedAt: true,
    );

    expect(data, isNot(contains('email')));
    expect(data, isNot(contains('city')));
    expect(data, isNot(contains('district')));
    expect(data, isNot(contains('createdAt')));
    expect(data, containsPair('username', 'Updated Name'));
    expect(data, containsPair('updatedAt', 'server-time'));
  });

  test(
    'profile finalization completes before Home user initialization',
    () async {
      final events = <String>[];

      await finalizePhoneSignupBeforeInitialization(
        authenticatedUid: 'user-b',
        input: input,
        finalizeProfile: (uid, profile) async {
          events.add('profile-finalized:$uid');
        },
        initializeUserB: () async {
          events.add('user-b-initialized');
        },
      );

      expect(events, ['profile-finalized:user-b', 'user-b-initialized']);
    },
  );
}
