/// Stable client-side classification for the email verification endpoint.
///
/// The endpoint currently returns human-readable errors, so keep the matching
/// narrow and translate them into the UX states used by VerifyEmailPage.
enum EmailVerificationFailure { invalidCode, expiredCode, network }

class EmailVerificationResendGuard {
  const EmailVerificationResendGuard._();

  static bool canResend({
    required bool isVerifying,
    required bool isResending,
    required int cooldownSeconds,
  }) {
    return !isVerifying && !isResending && cooldownSeconds == 0;
  }

  static bool isChangeEmailResult(Object? result) => result == false;
}

class EmailVerificationRecoveryPolicy {
  const EmailVerificationRecoveryPolicy._();

  static bool canRecoverExistingAccount({required bool emailVerified}) {
    return !emailVerified;
  }

  static bool shouldDeleteCreatedAccount({required bool emailVerified}) {
    return !emailVerified;
  }

  static bool canReusePersistedSession({
    required bool emailMatches,
    required bool userMatches,
    required bool requestIdPresent,
  }) {
    return emailMatches && userMatches && requestIdPresent;
  }
}

EmailVerificationFailure classifyEmailVerificationFailure({
  required int statusCode,
  String? serverError,
}) {
  final normalized = (serverError ?? '').toLowerCase();

  if (normalized.contains('expired') ||
      normalized.contains('not found') ||
      normalized.contains('too many attempts')) {
    return EmailVerificationFailure.expiredCode;
  }

  if (statusCode >= 400 && statusCode < 500) {
    return EmailVerificationFailure.invalidCode;
  }

  return EmailVerificationFailure.network;
}
