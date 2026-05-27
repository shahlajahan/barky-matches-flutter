import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String _strength = "";

  // 🔥 Password strength logic
  void _checkStrength(String password) {
    if (password.length < 6) {
      _strength = "Weak";
    } else if (password.length < 10) {
      _strength = "Medium";
    } else {
      _strength = "Strong";
    }

    setState(() {});
  }

  bool get _isValid {
    return _currentPasswordController.text.isNotEmpty &&
        _newPasswordController.text.length >= 6 &&
        _newPasswordController.text == _confirmPasswordController.text;
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      // 🔐 re-auth
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);

      // 🔄 update password
      await user.updatePassword(_newPasswordController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated successfully")),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _strength = "";
      });
    } on FirebaseAuthException catch (e) {
      String msg = "Something went wrong";

      if (e.code == 'wrong-password') {
        msg = "Current password is incorrect";
      } else if (e.code == 'weak-password') {
        msg = "New password is too weak";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color get _strengthColor {
    if (_strength == "Weak") {
      return Colors.red;
    }

    if (_strength == "Medium") {
      return Colors.orange;
    }

    return Colors.green;
  }

  Widget _buildStrengthIndicator() {
    if (_strength.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(
        color: _strengthColor.withOpacity(.08),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: _strengthColor.withOpacity(.2)),
      ),

      child: Row(
        children: [
          Icon(LucideIcons.shieldCheck, size: 18, color: _strengthColor),

          const SizedBox(width: 10),

          Text(
            "Password Strength:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            _strength,
            style: GoogleFonts.poppins(
              color: _strengthColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,

      labelStyle: GoogleFonts.poppins(),

      filled: true,
      fillColor: Colors.white,

      prefixIcon: Icon(icon, color: const Color(0xFF9E1B4F)),

      suffixIcon: IconButton(
        icon: Icon(
          obscure ? LucideIcons.eye : LucideIcons.eyeOff,
          color: Colors.black54,
          size: 20,
        ),
        onPressed: onToggle,
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF9E1B4F), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // 🟣 HEADER
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9E1B4F), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius: BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.lock,
                      color: Color(0xFFFFC107),
                      size: 34,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "Change Password",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFC107),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Keep your PetSupo account secure by updating your password regularly.",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.92),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 🔐 CURRENT PASSWORD
              Text(
                "Current Password",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _currentPasswordController,

                obscureText: _obscureCurrent,

                decoration: _inputDecoration(
                  label: "Enter current password",
                  icon: LucideIcons.lock,
                  obscure: _obscureCurrent,
                  onToggle: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 🆕 NEW PASSWORD
              Text(
                "New Password",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _newPasswordController,

                obscureText: _obscureNew,

                onChanged: _checkStrength,

                decoration: _inputDecoration(
                  label: "Enter new password",
                  icon: LucideIcons.keyRound,
                  obscure: _obscureNew,
                  onToggle: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
              ),

              const SizedBox(height: 14),

              _buildStrengthIndicator(),

              const SizedBox(height: 24),

              // 🔁 CONFIRM PASSWORD
              Text(
                "Confirm Password",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _confirmPasswordController,

                obscureText: _obscureConfirm,

                decoration: _inputDecoration(
                  label: "Confirm new password",
                  icon: LucideIcons.shieldCheck,
                  obscure: _obscureConfirm,
                  onToggle: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),

              const SizedBox(height: 40),

              // 🚀 BUTTON
              SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  onPressed: (!_isValid || _loading) ? null : _changePassword,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E1B4F),

                    foregroundColor: Colors.white,

                    elevation: 0,

                    disabledBackgroundColor: Colors.grey.shade300,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),

                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Update Password",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
