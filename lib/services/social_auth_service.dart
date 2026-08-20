import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_auth_browser_info.dart';

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
    this.isTemporaryAppleAccount = false,
    this.isAccountRecovery = false,
  });

  final User user;
  final SocialAuthProvider provider;
  final bool isNewProfile;
  final Map<String, dynamic> profile;
  final bool isTemporaryAppleAccount;
  final bool isAccountRecovery;

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
    // 'isPremium' is deliberately omitted: it is a backend-owned entitlement
    // field (see protectedUserCreateFields() in firestore.rules) and every
    // new profile is free/normal by default without needing to state it
    // explicitly. Sending it here previously caused Firestore Rules to
    // reject the entire create, leaving the Auth account without a profile.
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
  static bool _redirectResultRead = false;
  static bool _redirectResultReadInProgress = false;

  SocialAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
       _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  GoogleSignIn? _googleSignIn;

  @visibleForTesting
  static bool shouldCreateGoogleSignIn({required bool isWeb}) => !isWeb;

  GoogleSignIn get _mobileGoogleSignIn {
    final existing = _googleSignIn;
    if (existing != null) return existing;

    final created = GoogleSignIn(scopes: const ['email']);
    _googleSignIn = created;
    return created;
  }

  static bool get supportsApple =>
      supportsAppleOnPlatform(isWeb: kIsWeb, platform: defaultTargetPlatform);

  Future<SocialProfileResult?> signInWithGoogle({bool? isLoginMode}) async {
    try {
      final credential = await _signInGoogleCredential(
        isLoginMode: isLoginMode,
      );
      if (credential == null || credential.user == null) return null;
      return _finalize(credential, SocialAuthProvider.google);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<User> authenticateGoogleForAccountRecovery({bool? isLoginMode}) async {
    final credential = await _signInGoogleCredential(isLoginMode: isLoginMode);
    if (credential == null) {
      throw FirebaseAuthException(
        code: 'redirect-pending',
        message: 'Google authentication is continuing in the browser.',
      );
    }
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Authentication completed without a Firebase user.',
      );
    }
    if (credential.additionalUserInfo?.isNewUser == true) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'recovery-account-not-found',
        message: 'The selected Google account has no existing PetSupo account.',
      );
    }
    return user;
  }

  Future<UserCredential?> _signInGoogleCredential({bool? isLoginMode}) async {
    try {
      if (!shouldCreateGoogleSignIn(isWeb: kIsWeb)) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters(googleWebCustomParameters());
        return _webSignIn(provider, isLoginMode: isLoginMode);
      }
      final account = await _mobileGoogleSignIn.signIn();
      if (account == null) throw const SocialAuthCancelled();
      final authentication = await account.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      return _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<SocialProfileResult?> signInWithApple({bool? isLoginMode}) async {
    if (!supportsApple) throw UnsupportedError('Apple sign-in unsupported');

    UserCredential? credential;
    try {
      final provider = AppleAuthProvider();
      credential = kIsWeb
          ? await _webSignIn(provider, isLoginMode: isLoginMode)
          : await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'canceled' ||
          error.code == 'cancelled') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }

    if (credential == null) return null;

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Authentication completed without a Firebase user.',
      );
    }

    if (shouldHoldNewAppleSession(
      isNewUser: credential.additionalUserInfo?.isNewUser == true,
    )) {
      return SocialProfileResult(
        user: user,
        provider: SocialAuthProvider.apple,
        isNewProfile: true,
        profile: const <String, dynamic>{},
        isTemporaryAppleAccount: true,
      );
    }

    return _finalizeUser(user, SocialAuthProvider.apple);
  }

  Future<SocialProfileResult?> consumeWebRedirectResult() async {
    if (!kIsWeb || !isMobileSafariWeb) return null;
    if (_redirectResultRead || _redirectResultReadInProgress) return null;

    _redirectResultReadInProgress = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final providerName = preferences.getString(_pendingProviderKey);
      if (providerName == null) return null;

      _redirectResultRead = true;
      late final UserCredential credential;
      try {
        credential = await _auth.getRedirectResult();
      } on FirebaseAuthException catch (error) {
        if (error.code == 'popup-closed-by-user' ||
            error.code == 'cancelled-popup-request' ||
            error.code == 'canceled' ||
            error.code == 'cancelled') {
          await _clearPendingRedirect(preferences);
          throw const SocialAuthCancelled();
        }
        rethrow;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      final credentialUser = credential.user;
      var acceptedPostRedirectUser = false;
      if (credentialUser == null) {
        final preRedirectUid = preferences.getString(_preRedirectUidKey);
        final attemptId = preferences.getString(_redirectAttemptIdKey);
        final redirectStartedAt = preferences.getInt(_redirectStartedAtKey);
        final signedOutBeforeRedirect =
            preferences.getBool(_preRedirectSignedOutKey) == true;
        acceptedPostRedirectUser = canAcceptNullRedirectUser(
          signedOutBeforeRedirect: signedOutBeforeRedirect,
          redirectAttemptId: attemptId,
          redirectStartedAt: redirectStartedAt,
          currentUserUid: currentUser?.uid,
          preRedirectUid: preRedirectUid,
        );
        if (acceptedPostRedirectUser) {
        } else {
          await _clearPendingRedirect(preferences);
          throw FirebaseAuthException(
            code: 'redirect-user-unresolved',
            message:
                'The Web redirect completed without a verifiable Firebase user.',
          );
        }
      }

      late final User user;
      if (credentialUser != null) {
        user = credentialUser;
      } else if (acceptedPostRedirectUser) {
        user = currentUser!;
      } else {
        throw StateError('Unreachable unresolved redirect user state');
      }

      await _clearPendingRedirect(preferences);
      final provider = providerName == 'apple'
          ? SocialAuthProvider.apple
          : SocialAuthProvider.google;
      if (provider == SocialAuthProvider.apple) {
        if (shouldHoldNewAppleSession(
          isNewUser:
              credentialUser != null &&
              credential.additionalUserInfo?.isNewUser == true,
        )) {
          return SocialProfileResult(
            user: user,
            provider: provider,
            isNewProfile: true,
            profile: const <String, dynamic>{},
            isTemporaryAppleAccount: true,
          );
        }
        return _finalizeUser(user, provider);
      }
      return credentialUser == null
          ? _finalizeUser(user, provider)
          : _finalize(credential, provider);
    } finally {
      _redirectResultReadInProgress = false;
    }
  }

  Future<bool> hasPendingWebRedirect() async {
    if (!kIsWeb || !isMobileSafariWeb) return false;
    final preferences = await SharedPreferences.getInstance();
    return shouldResumeWebRedirectAtStartup(
      isWeb: kIsWeb,
      isMobileSafari: isMobileSafariWeb,
      hasPendingState: preferences.containsKey(_pendingProviderKey),
    );
  }

  Future<bool?> pendingWebRedirectLoginMode() async {
    if (!kIsWeb || !isMobileSafariWeb) return null;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_pendingLoginModeKey);
  }

  Future<String?> pendingWebRedirectProvider() async {
    if (!kIsWeb || !isMobileSafariWeb) return null;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingProviderKey);
  }

  Future<SocialProfileResult> linkAppleAccount({
    bool isAccountRecovery = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      throw FirebaseAuthException(
        code: 'requires-authentication',
        message: 'An authenticated user is required to link Apple.',
      );
    }
    if (_hasProvider(currentUser, 'apple.com')) {
      return _linkedUserResult(
        currentUser,
        isAccountRecovery: isAccountRecovery,
      );
    }

    final provider = AppleAuthProvider();
    final uidBefore = currentUser.uid;
    try {
      final credential = kIsWeb
          ? await currentUser.linkWithPopup(provider)
          : await currentUser.linkWithProvider(provider);
      final linkedUser = credential.user;
      if (!appleLinkPreservesUid(
        uidBefore: uidBefore,
        uidAfter: linkedUser?.uid,
        providerIds:
            linkedUser?.providerData.map((p) => p.providerId) ??
            const <String>[],
      )) {
        throw FirebaseAuthException(
          code: 'apple-link-verification-failed',
          message: 'Apple linking did not preserve the authenticated user.',
        );
      }
      return _linkedUserResult(
        linkedUser!,
        isAccountRecovery: isAccountRecovery,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'canceled' ||
          error.code == 'cancelled') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<SocialProfileResult> finalizeNewAppleAccount(User user) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != user.uid) {
      throw FirebaseAuthException(
        code: 'apple-session-changed',
        message: 'The temporary Apple session is no longer active.',
      );
    }
    return _finalizeUser(user, SocialAuthProvider.apple);
  }

  Future<void> deleteTemporaryAppleAccount(User user) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null ||
        currentUser.uid != user.uid ||
        !_hasProvider(currentUser, 'apple.com')) {
      throw FirebaseAuthException(
        code: 'apple-session-changed',
        message: 'The temporary Apple session is no longer active.',
      );
    }
    await currentUser.delete();
    if (_auth.currentUser != null) {
      throw FirebaseAuthException(
        code: 'apple-session-delete-failed',
        message: 'The temporary Apple account could not be removed.',
      );
    }
  }

  Future<SocialProfileResult> _linkedUserResult(
    User user, {
    required bool isAccountRecovery,
  }) async {
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return SocialProfileResult(
      user: user,
      provider: SocialAuthProvider.apple,
      isNewProfile: false,
      profile: Map<String, dynamic>.from(snapshot.data() ?? const {}),
      isAccountRecovery: isAccountRecovery,
    );
  }

  Future<SocialProfileResult> _finalize(
    UserCredential credential,
    SocialAuthProvider provider,
  ) async {
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Authentication completed without a Firebase user.',
      );
    }
    return _finalizeUser(user, provider);
  }

  Future<SocialProfileResult> _finalizeUser(
    User user,
    SocialAuthProvider provider,
  ) async {
    final providerId = provider == SocialAuthProvider.google
        ? 'google.com'
        : 'apple.com';
    final reference = _firestore.collection('users').doc(user.uid);
    final snapshot = await reference.get();
    bool isNewProfile;
    Map<String, dynamic> profile;

    if (snapshot.exists) {
      isNewProfile = false;
      profile = Map<String, dynamic>.from(snapshot.data() ?? {});
      await reference.set(
        buildSocialProfileLoginMetadata(
          providerId: providerId,
          serverTimestamp: FieldValue.serverTimestamp(),
          providerArrayValue: FieldValue.arrayUnion([providerId]),
        ),
        SetOptions(merge: true),
      );
    } else {
      // Server-owned, idempotent provisioning (see ensureUserProfile in
      // functions/user/ensureUserProfileCore.js) replaces a direct
      // client-side create. The Function derives every field from this
      // user's own Auth record and never accepts entitlement/role fields
      // from the client, so it cannot be rejected by protectedUserCreateFields
      // regardless of what a future client accidentally sends.
      await _functions.httpsCallable('ensureUserProfile').call();
      final created = await reference.get();
      if (!created.exists) {
        throw FirebaseAuthException(
          code: 'profile-provisioning-failed',
          message: 'Unable to create the user profile after sign-in.',
        );
      }
      isNewProfile = true;
      profile = Map<String, dynamic>.from(created.data() ?? {});
    }

    return SocialProfileResult(
      user: user,
      provider: provider,
      isNewProfile: isNewProfile,
      profile: profile,
    );
  }

  bool _hasProvider(User user, String providerId) {
    return user.providerData.any(
      (provider) => provider.providerId == providerId,
    );
  }

  Future<UserCredential?> _webSignIn(
    AuthProvider provider, {
    bool? isLoginMode,
  }) async {
    if (!shouldUseWebRedirect(
      isWeb: kIsWeb,
      isMobileSafari: isMobileSafariWeb,
    )) {
      return _auth.signInWithPopup(provider);
    }

    final preferences = await SharedPreferences.getInstance();
    final preRedirectUid = _auth.currentUser?.uid;
    final redirectAttemptId =
        '${DateTime.now().microsecondsSinceEpoch}-${provider.providerId}';
    await preferences.setString(
      _pendingProviderKey,
      provider.providerId == 'apple.com' ? 'apple' : 'google',
    );
    if (isLoginMode != null) {
      await preferences.setBool(_pendingLoginModeKey, isLoginMode);
    }
    if (preRedirectUid == null) {
      await preferences.remove(_preRedirectUidKey);
    } else {
      await preferences.setString(_preRedirectUidKey, preRedirectUid);
    }
    await preferences.setString(_redirectAttemptIdKey, redirectAttemptId);
    await preferences.setInt(
      _redirectStartedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await preferences.setBool(_preRedirectSignedOutKey, false);

    final authStateAfterSignOut = _auth.authStateChanges().firstWhere((user) {
      return user == null;
    });
    try {
      await _auth.signOut();
      await authStateAfterSignOut.timeout(const Duration(seconds: 10));
    } catch (_) {
      await _clearPendingRedirect(preferences);
      rethrow;
    }
    await preferences.setBool(_preRedirectSignedOutKey, true);

    await _auth.signInWithRedirect(provider);
    return null;
  }

  Future<void> _clearPendingRedirect(SharedPreferences preferences) async {
    await preferences.remove(_pendingProviderKey);
    await preferences.remove(_pendingLoginModeKey);
    await preferences.remove(_preRedirectUidKey);
    await preferences.remove(_redirectAttemptIdKey);
    await preferences.remove(_redirectStartedAtKey);
    await preferences.remove(_preRedirectSignedOutKey);
  }
}

const _pendingProviderKey = 'social_auth.pending_redirect_provider';
const _pendingLoginModeKey = 'social_auth.pending_redirect_login_mode';
const _preRedirectUidKey = 'social_auth.pending_redirect_pre_uid';
const _redirectAttemptIdKey = 'social_auth.pending_redirect_attempt_id';
const _redirectStartedAtKey = 'social_auth.pending_redirect_started_at';
const _preRedirectSignedOutKey = 'social_auth.pending_redirect_signed_out';

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

bool appleLinkPreservesUid({
  required String uidBefore,
  required String? uidAfter,
  required Iterable<String> providerIds,
}) {
  return uidAfter == uidBefore && providerIds.contains('apple.com');
}

bool shouldHoldNewAppleSession({required bool isNewUser}) => isNewUser;

bool shouldUseWebRedirect({required bool isWeb, required bool isMobileSafari}) {
  return isWeb && isMobileSafari;
}

Map<String, String> googleWebCustomParameters() {
  return const {'prompt': 'select_account'};
}

bool shouldResumeWebRedirectAtStartup({
  required bool isWeb,
  required bool isMobileSafari,
  required bool hasPendingState,
}) {
  return isWeb && isMobileSafari && hasPendingState;
}

bool canAcceptNullRedirectUser({
  required bool signedOutBeforeRedirect,
  required String? redirectAttemptId,
  required int? redirectStartedAt,
  required String? currentUserUid,
  required String? preRedirectUid,
}) {
  return signedOutBeforeRedirect &&
      redirectAttemptId != null &&
      redirectAttemptId.isNotEmpty &&
      redirectStartedAt != null &&
      redirectStartedAt > 0 &&
      currentUserUid != null &&
      currentUserUid != preRedirectUid;
}
