import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialAuthProvider { google, apple }

class SocialAuthCancelled implements Exception {
  const SocialAuthCancelled();
}

class SocialProfileResult {
  const SocialProfileResult({
    required this.user,
    required this.provider,
    required this.isNewProfile,
    required this.profile,
  });

  final User user;
  final SocialAuthProvider provider;
  final bool isNewProfile;
  final Map<String, dynamic> profile;

  bool get needsCompletion => socialProfileMissingFields(profile).isNotEmpty;
}

List<String> socialProfileMissingFields(
  Map<String, dynamic> profile, {
  bool requireTerms = true,
}) {
  final missing = <String>[];
  for (final field in const ['username', 'city', 'district']) {
    if ((profile[field] ?? '').toString().trim().isEmpty) missing.add(field);
  }
  if (requireTerms && profile['termsAccepted'] != true) {
    missing.add('termsAccepted');
  }
  return missing;
}

Map<String, dynamic> buildSocialProfileCreationData({
  required String uid,
  required String providerId,
  required String email,
  required String displayName,
  required String photoUrl,
  required Object serverTimestamp,
}) {
  final fallbackUsername = displayName.trim().isNotEmpty
      ? displayName.trim()
      : email.split('@').first;
  return {
    'uid': uid,
    'username': fallbackUsername,
    'email': email.trim().toLowerCase(),
    'phone': '',
    'city': '',
    'district': '',
    'photoUrl': photoUrl.trim(),
    'isPremium': false,
    'emailVerified': true,
    'profileCompleted': false,
    'authProvider': providerId,
    'authProviders': [providerId],
    'createdAt': serverTimestamp,
    'updatedAt': serverTimestamp,
    'lastLoginAt': serverTimestamp,
  };
}

Map<String, dynamic> buildSocialProfileLoginMetadata({
  required String providerId,
  required Object serverTimestamp,
  required Object providerArrayValue,
}) {
  return {
    'authProvider': providerId,
    'authProviders': providerArrayValue,
    'lastLoginAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };
}

class SocialAuthService {
  SocialAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  static bool get supportsApple =>
      supportsAppleOnPlatform(isWeb: kIsWeb, platform: defaultTargetPlatform);

  Future<SocialProfileResult> signInWithGoogle() async {
    try {
      UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final account = await _googleSignIn.signIn();
        if (account == null) throw const SocialAuthCancelled();
        final authentication = await account.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        );
        credential = await _auth.signInWithCredential(oauthCredential);
      }
      return _finalize(credential, SocialAuthProvider.google);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<SocialProfileResult> signInWithApple() async {
    if (!supportsApple) throw UnsupportedError('Apple sign-in unsupported');

    UserCredential credential;
    String appleDisplayName = '';
    try {
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(AppleAuthProvider());
      } else {
        final rawNonce = _generateNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );
        final identityToken = appleCredential.identityToken;
        if (identityToken == null || identityToken.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-apple-identity-token',
            message: 'Apple did not return an identity token.',
          );
        }
        appleDisplayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
        final oauthCredential = OAuthProvider(
          'apple.com',
        ).credential(idToken: identityToken, rawNonce: rawNonce);
        credential = await _auth.signInWithCredential(oauthCredential);
        if (appleDisplayName.isNotEmpty &&
            (credential.user?.displayName ?? '').trim().isEmpty) {
          await credential.user?.updateDisplayName(appleDisplayName);
        }
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SocialAuthCancelled();
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
    return _finalize(
      credential,
      SocialAuthProvider.apple,
      providerDisplayName: appleDisplayName,
    );
  }

  Future<SocialProfileResult> _finalize(
    UserCredential credential,
    SocialAuthProvider provider, {
    String providerDisplayName = '',
  }) async {
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Authentication completed without a Firebase user.',
      );
    }
    final providerId = provider == SocialAuthProvider.google
        ? 'google.com'
        : 'apple.com';
    final reference = _firestore.collection('users').doc(user.uid);
    late bool isNewProfile;
    late Map<String, dynamic> profile;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final now = FieldValue.serverTimestamp();
      if (snapshot.exists) {
        isNewProfile = false;
        profile = Map<String, dynamic>.from(snapshot.data() ?? {});
        transaction.set(
          reference,
          buildSocialProfileLoginMetadata(
            providerId: providerId,
            serverTimestamp: now,
            providerArrayValue: FieldValue.arrayUnion([providerId]),
          ),
          SetOptions(merge: true),
        );
      } else {
        isNewProfile = true;
        profile = buildSocialProfileCreationData(
          uid: user.uid,
          providerId: providerId,
          email: user.email ?? '',
          displayName: providerDisplayName.isNotEmpty
              ? providerDisplayName
              : user.displayName ?? '',
          photoUrl: user.photoURL ?? '',
          serverTimestamp: now,
        );
        transaction.set(reference, profile);
      }
    });

    return SocialProfileResult(
      user: user,
      provider: provider,
      isNewProfile: isNewProfile,
      profile: profile,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}

bool supportsAppleOnPlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;
}

bool shouldShowAppleSignIn({required bool enabled, required bool supported}) {
  return enabled && supported;
}
