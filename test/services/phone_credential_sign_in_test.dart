import 'package:barky_matches_fixed/services/phone_credential_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signInToIndependentPhoneAccount', () {
    test(
      'User A phone signup signs into User B without preserving A',
      () async {
        var firebaseUid = 'user-a';
        var signInCalls = 0;

        final result = await signInToIndependentPhoneAccount(
          signIn: () async {
            signInCalls++;
            firebaseUid = 'user-b';
            return firebaseUid;
          },
          readAuthenticatedUid: () => firebaseUid,
        );

        expect(result, 'user-b');
        expect(result, isNot('user-a'));
        expect(firebaseUid, 'user-b');
        expect(signInCalls, 1);
      },
    );

    test('rejects a result that differs from Firebase currentUser', () async {
      expect(
        () => signInToIndependentPhoneAccount(
          signIn: () async => 'user-b',
          readAuthenticatedUid: () => 'user-a',
        ),
        throwsA(isA<PhoneSignInIdentityException>()),
      );
    });
  });
}
