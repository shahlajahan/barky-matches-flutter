import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    if (user == null || user.email == null) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated successfully")),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = "Something went wrong";

      if (e.code == 'wrong-password') {
        msg = "Current password is incorrect";
      } else if (e.code == 'weak-password') {
        msg = "New password is too weak";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildStrengthIndicator() {
    Color color;
    if (_strength == "Weak") {
      color = Colors.red;
    } else if (_strength == "Medium") {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return Row(
      children: [
        Text("Strength: "),
        Text(
          _strength,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 🔐 Current password
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: "Current Password",
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 🆕 New password
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  onChanged: _checkStrength,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                _buildStrengthIndicator(),

                const SizedBox(height: 16),

                // 🔁 Confirm password
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 🚀 Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!_isValid || _loading)
                        ? null
                        : _changePassword,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text("Update Password"),
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