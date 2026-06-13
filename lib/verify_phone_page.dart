import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifyPhonePage extends StatefulWidget {
  final String phone;

  final String userId;

  const VerifyPhonePage({super.key, required this.phone, required this.userId});

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final TextEditingController _codeController = TextEditingController();

  bool _loading = false;

  String? verificationId;

  @override
  void initState() {
    super.initState();

    _sendCode();
  }

  Future<void> _sendCode() async {
    verificationId = null;

    debugPrint('==== FIREBASE APP INFO ====');

debugPrint(
  'APP ID: ${FirebaseAuth.instance.app.options.appId}',
);

debugPrint(
  'PROJECT ID: ${FirebaseAuth.instance.app.options.projectId}',
);

debugPrint(
  'SENDER ID: ${FirebaseAuth.instance.app.options.messagingSenderId}',
);

debugPrint(
  'PHONE AUTH: ${widget.phone}',
);

debugPrint('===========================');

    debugPrint('VERIFY PAGE SEND CODE CALLED');

    debugPrint('PHONE => ${widget.phone}');

    final auth = FirebaseAuth.instance;

debugPrint("========== PHONE AUTH DIAGNOSTIC ==========");
debugPrint("currentUser: ${auth.currentUser?.uid}");
debugPrint("providerData: ${auth.currentUser?.providerData}");
debugPrint("isAnonymous: ${auth.currentUser?.isAnonymous}");
debugPrint("phone: ${auth.currentUser?.phoneNumber}");
debugPrint("email: ${auth.currentUser?.email}");

try {
  final token = await auth.currentUser?.getIdToken();
  debugPrint("idToken exists: ${token != null}");
} catch (e) {
  debugPrint("idToken ERROR: $e");
}

debugPrint("===========================================");

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,

      verificationCompleted: (credential) {},

      verificationFailed: (e) {
        debugPrint('PHONE VERIFY FAILED: ${e.code}');

        debugPrint('PHONE VERIFY MESSAGE: ${e.message}');

        debugPrint('PHONE VERIFY FULL: $e');

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${e.code}\n${e.message}')));
        }
      },

      codeSent: (id, resend) {
        verificationId = id;

        debugPrint('CODE SENT');

        debugPrint('VERIFICATION ID = $id');
      },

      codeAutoRetrievalTimeout: (id) {
        verificationId = id;

        debugPrint('TIMEOUT ID = $id');
      },
    );
  }

  Future<void> _verify() async {
    if (verificationId == null || _codeController.text.length != 6) return;

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,

        smsCode: _codeController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final authUser = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .set({
            'uid': authUser.uid,

            'phone': widget.phone,

            'phoneVerified': true,

            'createdAt': FieldValue.serverTimestamp(),

            'username': '',

            'email': '',
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .set({
            'phone': widget.phone,

            'phoneVerified': true,

            'phoneVerifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => _loading = false);
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

                      child: const Text(
                        "Change Number",

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
                  "Verify Phone",

                  style: GoogleFonts.dancingScript(
                    fontSize: 42,

                    fontWeight: FontWeight.w700,

                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Enter code sent to\n${widget.phone}",

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

                    labelText: "Code",

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
                        : const Text(
                            "Verify",

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
                      const SnackBar(content: Text("New code sent")),
                    );
                  },

                  child: const Text(
                    "Resend Code",

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
