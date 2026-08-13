import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:barky_matches_fixed/auth/email_verification_flow.dart';
import 'package:barky_matches_fixed/auth_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/barky-email-verification-ui-test');
    await Hive.openBox<String>('currentUserBox');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('email verification failure classification', () {
    test('wrong code is an invalid-code failure', () {
      expect(
        classifyEmailVerificationFailure(
          statusCode: 400,
          serverError: 'Invalid verification code',
        ),
        EmailVerificationFailure.invalidCode,
      );
    });

    test('expired code is an expired-code failure', () {
      expect(
        classifyEmailVerificationFailure(
          statusCode: 400,
          serverError: 'Code expired',
        ),
        EmailVerificationFailure.expiredCode,
      );
    });

    test('server and network failures are not shown as invalid codes', () {
      expect(
        classifyEmailVerificationFailure(
          statusCode: 500,
          serverError: 'Service unavailable',
        ),
        EmailVerificationFailure.network,
      );
    });
  });

  group('verification recovery actions', () {
    test('resend is blocked while sending or during cooldown', () {
      expect(
        EmailVerificationResendGuard.canResend(
          isVerifying: false,
          isResending: true,
          cooldownSeconds: 0,
        ),
        isFalse,
      );
      expect(
        EmailVerificationResendGuard.canResend(
          isVerifying: false,
          isResending: false,
          cooldownSeconds: 12,
        ),
        isFalse,
      );
      expect(
        EmailVerificationResendGuard.canResend(
          isVerifying: false,
          isResending: false,
          cooldownSeconds: 0,
        ),
        isTrue,
      );
    });

    test('change email is represented by a false route result', () {
      expect(EmailVerificationResendGuard.isChangeEmailResult(false), isTrue);
      expect(EmailVerificationResendGuard.isChangeEmailResult(null), isFalse);
      expect(EmailVerificationResendGuard.isChangeEmailResult(true), isFalse);
    });

    test('signup recovery can resend a persisted session after restart', () {
      expect(
        EmailVerificationRecoveryPolicy.canReusePersistedSession(
          emailMatches: true,
          userMatches: true,
          requestIdPresent: true,
        ),
        isTrue,
      );
    });

    test('changing email permits cleanup of the unverified account', () {
      expect(
        EmailVerificationRecoveryPolicy.shouldDeleteCreatedAccount(
          emailVerified: false,
        ),
        isTrue,
      );
    });

    test('verified accounts cannot use unverified signup recovery', () {
      expect(
        EmailVerificationRecoveryPolicy.canRecoverExistingAccount(
          emailVerified: true,
        ),
        isFalse,
      );
    });

    test('unverified existing accounts can use recovery', () {
      expect(
        EmailVerificationRecoveryPolicy.canRecoverExistingAccount(
          emailVerified: false,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'verification page presents email hierarchy and visible change action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VerifyEmailPage(
            email: 'person@example.com',
            userId: 'test-user',
            requestId: 'test-request',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verification code sent to'), findsOneWidget);
      expect(find.text('person@example.com'), findsOneWidget);
      expect(find.text('Change email'), findsOneWidget);
    },
  );
}
