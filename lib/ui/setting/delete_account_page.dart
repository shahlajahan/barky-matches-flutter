import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/welcome_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() =>
      _DeleteAccountPageState();
}

class _DeleteAccountPageState
    extends State<DeleteAccountPage> {

  final TextEditingController _confirmController =
      TextEditingController();

  bool _isLoading = false;

  bool get _canDelete =>
      _confirmController.text
          .trim()
          .toLowerCase() ==
      "delete";

  Future<void> _deleteAccount() async {

    setState(() => _isLoading = true);

    try {

      final callable =
          FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable(
        'deleteUserAccount',
      );

      await callable.call();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        ),
        (route) => false,
      );

    } catch (e) {

      debugPrint("❌ delete error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Failed to delete account. Please try again.",
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDelete() {

    showDialog(
      context: context,

      builder: (_) {

        return Dialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(28),
          ),

          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                Container(
                  width: 80,
                  height: 80,

                  decoration: BoxDecoration(
                    color:
                        Colors.red.withOpacity(.10),

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    LucideIcons.trash2,
                    color: Colors.red,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Delete Account",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  "This action is permanent.\n\nAll your dogs, chats, favorites, and activity will be permanently deleted.",
                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },

                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.black87,

                          side: BorderSide(
                            color:
                                Colors.grey.shade300,
                          ),

                          minimumSize:
                              const Size(0, 52),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    16),
                          ),
                        ),

                        child: Text(
                          "Cancel",
                          style:
                              GoogleFonts.poppins(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteAccount();
                        },

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.red,

                          foregroundColor:
                              Colors.white,

                          elevation: 0,

                          minimumSize:
                              const Size(0, 52),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    16),
                          ),
                        ),

                        child: Text(
                          "Delete",
                          style:
                              GoogleFonts.poppins(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {

    _confirmController.dispose();

    super.dispose();
  }

  InputDecoration _inputDecoration() {

    return InputDecoration(

      hintText: 'DELETE',

      labelText: 'Type DELETE to confirm',

      labelStyle: GoogleFonts.poppins(),

      filled: true,
      fillColor: Colors.white,

      prefixIcon: const Icon(
        LucideIcons.shieldAlert,
        color: Colors.red,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),

      errorText:
          _confirmController.text.isNotEmpty &&
                  !_canDelete
              ? 'Please type DELETE exactly'
              : null,
    );
  }

  Widget _buildDangerItem(String text) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        children: [

          const Icon(
            LucideIcons.alertTriangle,
            color: Colors.red,
            size: 18,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            120,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // 🔴 HEADER
              Container(
                width: double.infinity,

                padding:
                    const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF8B0000),
                      Color(0xFFD32F2F),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius:
                      BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.red
                          .withOpacity(.18),
                      blurRadius: 18,
                      offset:
                          const Offset(0, 8),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    const Icon(
                      LucideIcons.shieldAlert,
                      color:
                          Color(0xFFFFC107),
                      size: 36,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "Delete Account",
                      style:
                          GoogleFonts.poppins(
                        color:
                            const Color(
                                0xFFFFC107),
                        fontSize: 26,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "This action is permanent and cannot be undone.",
                      style:
                          GoogleFonts.poppins(
                        color: Colors.white
                            .withOpacity(.92),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ⚠️ WARNING CARD
              Container(
                width: double.infinity,

                padding:
                    const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(
                          24),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(.04),
                      blurRadius: 12,
                      offset:
                          const Offset(0, 5),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(
                      children: [

                        const Icon(
                          LucideIcons.alertOctagon,
                          color: Colors.red,
                          size: 22,
                        ),

                        const SizedBox(width: 10),

                        Text(
                          "What will be deleted",
                          style:
                              GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    _buildDangerItem(
                      "Your profile and account information",
                    ),

                    _buildDangerItem(
                      "All your dogs and pet profiles",
                    ),

                    _buildDangerItem(
                      "Messages, chats, and favorites",
                    ),

                    _buildDangerItem(
                      "Appointments, activity, and saved data",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 🔐 CONFIRM INPUT
              Text(
                "Confirmation",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _confirmController,

                textCapitalization:
                    TextCapitalization.characters,

                onChanged: (_) {
                  setState(() {});
                },

                decoration: _inputDecoration(),
              ),

              const SizedBox(height: 40),

              // 🔴 DELETE BUTTON
              SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  onPressed:
                      _canDelete &&
                              !_isLoading
                          ? _confirmDelete
                          : null,

                  style: ElevatedButton
                      .styleFrom(
                    backgroundColor:
                        Colors.red,

                    foregroundColor:
                        Colors.white,

                    disabledBackgroundColor:
                        Colors.grey.shade300,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                              18),
                    ),
                  ),

                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [

                            const Icon(
                              LucideIcons.trash2,
                              size: 18,
                            ),

                            const SizedBox(width: 10),

                            Text(
                              "Delete Account",
                              style:
                                  GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
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