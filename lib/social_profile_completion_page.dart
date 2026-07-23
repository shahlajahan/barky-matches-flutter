import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';
import 'terms_page.dart';

class SocialProfileCompletionPage extends StatefulWidget {
  const SocialProfileCompletionPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<SocialProfileCompletionPage> createState() =>
      _SocialProfileCompletionPageState();
}

class _SocialProfileCompletionPageState
    extends State<SocialProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late bool _termsAccepted;
  bool _marketingConsent = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(
      text: (widget.profile['username'] ?? '').toString(),
    );
    _city = TextEditingController(
      text: (widget.profile['city'] ?? '').toString(),
    );
    _district = TextEditingController(
      text: (widget.profile['district'] ?? '').toString(),
    );
    _termsAccepted = widget.profile['termsAccepted'] == true;
    _marketingConsent = widget.profile['receiveNews'] == true;
  }

  @override
  void dispose() {
    _username.dispose();
    _city.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.termsRequired)));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': _username.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'receiveNews': _marketingConsent,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.unableToSignIn)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkPink = Color(0xFF9E1B4F);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF5A9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.completeYourProfile,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: darkPink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      controller: _username,
                      label: l10n.usernameLabel,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? l10n.usernameRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _city,
                      label: l10n.cityLabel,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? l10n.cityRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _district,
                      label: l10n.districtLabel,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? l10n.districtRequired
                          : null,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _termsAccepted,
                      activeColor: Colors.pink,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _termsAccepted = value ?? false),
                      title: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TermsPage()),
                        ),
                        child: Text(
                          l10n.termsAndConditionsLabel,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _marketingConsent,
                      activeColor: Colors.pink,
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _marketingConsent = value ?? false,
                            ),
                      title: Text(
                        l10n.receiveNewsLabel,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                l10n.continueLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFFF3F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
