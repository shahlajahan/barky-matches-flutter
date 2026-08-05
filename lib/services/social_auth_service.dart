import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      final credential = await _signInGoogleCredential();
      return _finalize(credential, SocialAuthProvider.google);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<User> authenticateGoogleForAccountRecovery() async {
    final credential = await _signInGoogleCredential();
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

  Future<UserCredential> _signInGoogleCredential() async {
    try {
      if (kIsWeb) {
        return _auth.signInWithPopup(GoogleAuthProvider());
      }
      final account = await _googleSignIn.signIn();
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

  Future<SocialProfileResult> signInWithApple() async {
    if (!supportsApple) throw UnsupportedError('Apple sign-in unsupported');

    UserCredential credential;
    try {
      final provider = AppleAuthProvider();
      credential = kIsWeb
          ? await _auth.signInWithPopup(provider)
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
          displayName: user.displayName ?? '',
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

  bool _hasProvider(User user, String providerId) {
    return user.providerData.any(
      (provider) => provider.providerId == providerId,
    );
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

bool appleLinkPreservesUid({
  required String uidBefore,
  required String? uidAfter,
  required Iterable<String> providerIds,
}) {
  return uidAfter == uidBefore && providerIds.contains('apple.com');
}

bool shouldHoldNewAppleSession({required bool isNewUser}) => isNewUser;
