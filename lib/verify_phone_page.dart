import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/services/phone_credential_sign_in.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class VerifyPhonePage extends StatefulWidget {
  final String phone;

  const VerifyPhonePage({super.key, required this.phone});

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final TextEditingController _codeController = TextEditingController();

  bool _loading = false;

  String? verificationId;

  void _debugPhoneAuth(String message) {
    if (kDebugMode) debugPrint('PHONE_AUTH_FLOW: $message');
  }

  @override
  void initState() {
    super.initState();

    _sendCode();
  }

  Future<void> _sendCode() async {
    verificationId = null;

    debugPrint('==== FIREBASE APP INFO ====');

    debugPrint('APP ID: ${FirebaseAuth.instance.app.options.appId}');

    debugPrint('PROJECT ID: ${FirebaseAuth.instance.app.options.projectId}');

    debugPrint(
      'SENDER ID: ${FirebaseAuth.instance.app.options.messagingSenderId}',
    );

    debugPrint('===========================');

    debugPrint('VERIFY PAGE SEND CODE CALLED');

    final auth = FirebaseAuth.instance;

    debugPrint("========== PHONE AUTH DIAGNOSTIC ==========");
    debugPrint("currentUser: ${auth.currentUser?.uid}");
    debugPrint("providerData: ${auth.currentUser?.providerData}");
    debugPrint("isAnonymous: ${auth.currentUser?.isAnonymous}");
    debugPrint("phonePresent: ${auth.currentUser?.phoneNumber != null}");
    debugPrint("email: ${auth.currentUser?.email}");

    try {
      final token = await auth.currentUser?.getIdToken();
      debugPrint("idToken exists: ${token != null}");
    } catch (e) {
      debugPrint("idToken ERROR: $e");
    }

    debugPrint("===========================================");

    _debugPhoneAuth('verifyPhoneNumber start');
    try {
      debugPrint('============= VERIFY REQUEST =============');
      debugPrint('Phone Number: ${widget.phone}');
      debugPrint('Current User: ${FirebaseAuth.instance.currentUser?.uid}');
      debugPrint('Firebase App: ${FirebaseAuth.instance.app.name}');
      debugPrint('Project: ${FirebaseAuth.instance.app.options.projectId}');
      debugPrint('AppId: ${FirebaseAuth.instance.app.options.appId}');
      debugPrint('API Key: ${FirebaseAuth.instance.app.options.apiKey}');
      debugPrint('==========================================');
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,

        verificationCompleted: (credential) {
          _debugPhoneAuth(
            'verificationCompleted callback; credentialPresent=true',
          );
        },

        verificationFailed: (FirebaseAuthException e) {
          _debugPhoneAuth('verificationFailed callback');

          debugPrint('');
          debugPrint('================ PHONE AUTH FAILED ================');
          debugPrint('TIME: ${DateTime.now()}');
          debugPrint('CODE: ${e.code}');
          debugPrint('MESSAGE: ${e.message}');
          debugPrint('PLUGIN: ${e.plugin}');
          debugPrint('EMAIL: ${e.email}');
          debugPrint('PHONE: ${widget.phone}');
          debugPrint('TENANT ID: ${e.tenantId}');
          debugPrint('CREDENTIAL: ${e.credential}');
          debugPrint('TOSTRING: ${e.toString()}');
          debugPrint('STACK TRACE:');
          debugPrint('${e.stackTrace}');
          debugPrint('===================================================');
          debugPrint('');

          FlutterError.reportError(
            FlutterErrorDetails(
              exception: e,
              stack: e.stackTrace,
              library: 'phone_auth',
              context: ErrorDescription('verificationFailed callback'),
            ),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 8),
                content: SingleChildScrollView(
                  child: Text(
                    AppLocalizations.of(context)!.phoneAuthDebugError(
                      e.code,
                      e.message ?? '',
                      e.toString(),
                    ),
                  ),
                ),
              ),
            );
          }
        },

        codeSent: (id, resend) {
          verificationId = id;

          _debugPhoneAuth(
            'codeSent callback; verificationIdPresent=${id.isNotEmpty}; '
            'resendTokenPresent=${resend != null}',
          );
          debugPrint('CODE SENT');
        },

        codeAutoRetrievalTimeout: (id) {
          verificationId = id;

          _debugPhoneAuth(
            'codeAutoRetrievalTimeout callback; '
            'verificationIdPresent=${id.isNotEmpty}',
          );
        },
      );
      _debugPhoneAuth('verifyPhoneNumber returned without synchronous error');
    } on FirebaseAuthException catch (e) {
      _debugPhoneAuth('verifyPhoneNumber threw; code=${e.code}');
      rethrow;
    } catch (e) {
      _debugPhoneAuth(
        'verifyPhoneNumber threw non-Firebase exception; type=${e.runtimeType}',
      );
      rethrow;
    }
  }

  Future<void> _verify() async {
    final hasVerificationId = verificationId?.isNotEmpty == true;
    final hasExpectedCodeLength = _codeController.text.length == 6;
    _debugPhoneAuth(
      'SMS submit tapped; verificationIdPresent=$hasVerificationId; '
      'codeLengthValid=$hasExpectedCodeLength',
    );
    if (!hasVerificationId || !hasExpectedCodeLength) {
      _debugPhoneAuth('SMS submit stopped by local precondition');
      return;
    }

    setState(() => _loading = true);

    try {
      late final PhoneAuthCredential credential;
      try {
        credential = PhoneAuthProvider.credential(
          verificationId: verificationId!,

          smsCode: _codeController.text.trim(),
        );
        _debugPhoneAuth('PhoneAuthCredential creation success');
      } catch (e) {
        _debugPhoneAuth(
          'PhoneAuthCredential creation failed; type=${e.runtimeType}',
        );
        rethrow;
      }

      final auth = FirebaseAuth.instance;
      final verifiedUid = await signInToIndependentPhoneAccount(
        signIn: () async {
          _debugPhoneAuth('signInWithCredential start');
          try {
            final result = await auth.signInWithCredential(credential);
            _debugPhoneAuth(
              'signInWithCredential success; userPresent=${result.user != null}; '
              'currentUserMatches=${result.user?.uid == auth.currentUser?.uid}',
            );
            return result.user?.uid;
          } on FirebaseAuthException catch (e) {
            _debugPhoneAuth('signInWithCredential exception; code=${e.code}');
            rethrow;
          } catch (e) {
            _debugPhoneAuth(
              'signInWithCredential non-Firebase exception; '
              'type=${e.runtimeType}',
            );
            rethrow;
          }
        },
        readAuthenticatedUid: () => auth.currentUser?.uid,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(verifiedUid)
          .set({
            'uid': verifiedUid,

            'phone': widget.phone,

            'phoneVerified': true,

            'phoneVerifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, verifiedUid);
    } on FirebaseAuthException catch (e) {
      _debugPhoneAuth('SMS submit FirebaseAuthException; code=${e.code}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_phoneSignInErrorMessage(e))));
    } on PhoneSignInIdentityException catch (e) {
      _debugPhoneAuth('SMS submit identity mismatch after sign-in');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      _debugPhoneAuth('SMS submit failed; type=${e.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.phoneVerificationFailed),
        ),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  String _phoneSignInErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'session-expired':
        return 'The verification session expired. Request a new code.';
      case 'user-disabled':
        return 'This phone account has been disabled.';
      default:
        return error.message ?? 'Phone verification could not be completed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,

          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],

              begin: Alignment.topLeft,

              end: Alignment.bottomRight,
            ),
          ),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Column(
              children: [
                const SizedBox(height: 40),

                /// BACK + CHANGE NUMBER
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },

                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),

                    const Spacer(),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },

                      child: Text(
                        AppLocalizations.of(context)!.changeNumber,

                        style: TextStyle(
                          color: Colors.white,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                Text(
                  AppLocalizations.of(context)!.verifyPhoneTitle,

                  style: GoogleFonts.dancingScript(
                    fontSize: 42,

                    fontWeight: FontWeight.w700,

                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  AppLocalizations.of(context)!.enterCodeSentTo(widget.phone),

                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    fontSize: 18,

                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: _codeController,

                  keyboardType: TextInputType.number,

                  maxLength: 6,

                  style: const TextStyle(color: Colors.white, fontSize: 24),

                  textAlign: TextAlign.center,

                  decoration: InputDecoration(
                    counterText: "",

                    filled: true,

                    fillColor: Colors.white24,

                    labelText: AppLocalizations.of(context)!.codeLabel,

                    labelStyle: const TextStyle(color: Colors.white70),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),

                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(.4),
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),

                      borderSide: const BorderSide(
                        color: Colors.amber,

                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: 220,

                  height: 60,

                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,

                      foregroundColor: Colors.black,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(
                            AppLocalizations.of(context)!.verifyButton,

                            style: TextStyle(
                              fontSize: 24,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () async {
                    await _sendCode();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.newCodeSent,
                        ),
                      ),
                    );
                  },

                  child: Text(
                    AppLocalizations.of(context)!.resendCode,

                    style: TextStyle(
                      fontSize: 22,

                      color: Colors.white,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
