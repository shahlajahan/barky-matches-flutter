import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/welcome_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;

  bool get _canDelete =>
      _confirmController.text.trim().toLowerCase() == "delete";

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('deleteUserAccount');

      await callable.call();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("❌ delete error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete account. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This action is permanent.\n\nAll your data including dogs, chats, and activity will be deleted.\n\nAre you sure?",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confirmController.dispose(); // 🔥 مهم (memory leak fix)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text("Delete Account"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Deleting your account will permanently remove:",
              style: GoogleFonts.poppins(fontSize: 14),
            ),

            const SizedBox(height: 12),

            /// ✅ Apple-friendly bullet list
            Text(
              "• Your profile\n"
              "• Your dogs\n"
              "• Messages & chats\n"
              "• Favorites & activity",
              style: GoogleFonts.poppins(fontSize: 13),
            ),

            const SizedBox(height: 20),

            /// ⚠️ Warning Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                "This action cannot be undone.",
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔐 Confirmation input
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                labelText: 'Type "DELETE" to confirm',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            /// 🔴 Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canDelete && !_isLoading ? _confirmDelete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Delete Account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}