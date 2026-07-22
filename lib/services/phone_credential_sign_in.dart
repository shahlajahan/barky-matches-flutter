class PhoneSignInIdentityException implements Exception {
  const PhoneSignInIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef SignInWithPhoneCredential = Future<String?> Function();
typedef ReadAuthenticatedUid = String? Function();

Future<String> signInToIndependentPhoneAccount({
  required SignInWithPhoneCredential signIn,
  required ReadAuthenticatedUid readAuthenticatedUid,
}) async {
  final signedInUid = await signIn();
  final authoritativeUid = readAuthenticatedUid();

  if (signedInUid == null || signedInUid != authoritativeUid) {
    throw const PhoneSignInIdentityException(
      'The authenticated Firebase account did not match the phone sign-in result.',
    );
  }

  return authoritativeUid!;
}
