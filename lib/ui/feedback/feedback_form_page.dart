import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  int rating = 0;

  String category = "general_feedback";

  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> submitFeedback() async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectRating),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection("user_feedback").add({
        "userId": uid,
        "rating": rating,
        "category": category,
        "message": messageController.text,

        "context": "manual_feedback",

        "platform": "flutter",

        "appVersion": "1.0.0",

        "status": "new",

        "priority": "normal",

        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      messageController.clear();

      setState(() {
        rating = 0;
        category = "general_feedback";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.feedbackSubmittedSuccessfully,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.feedbackSubmissionFailed(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Widget buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;

        final isSelected = rating >= starIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              rating = starIndex;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? const Color(0xFFFFC107).withOpacity(.18)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFFFC107),
              size: 34,
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,

      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF9E1B4F))
          : null,

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
          },

          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟣 HEADER CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),

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
                        Icons.favorite_rounded,
                        color: Color(0xFFFFC107),
                        size: 34,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        l10n.sendFeedback,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFC107),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        l10n.feedbackIntro,
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

                // ⭐ RATING
                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [
                      Text(
                        l10n.rateYourExperience,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9E1B4F),
                        ),
                      ),

                      const SizedBox(height: 18),

                      buildStars(),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 🟣 CATEGORY
                Text(
                  l10n.feedbackCategory,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9E1B4F),
                  ),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: category,

                  decoration: _inputDecoration(
                    label: "Select category",
                    icon: Icons.category_rounded,
                  ),

                  dropdownColor: Colors.white,

                  items: [
                    DropdownMenuItem(
                      value: "general_feedback",
                      child: Text(l10n.generalFeedback),
                    ),

                    DropdownMenuItem(value: "bug", child: Text(l10n.bugReport)),

                    DropdownMenuItem(
                      value: "feature_request",
                      child: Text(l10n.featureRequest),
                    ),
                  ],

                  onChanged: (value) {
                    setState(() {
                      category = value!;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // 🟣 MESSAGE
                Text(
                  l10n.yourMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9E1B4F),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: messageController,
                  maxLines: 6,

                  decoration: _inputDecoration(
                    label: "Write your feedback...",
                    icon: Icons.edit_note_rounded,
                  ),
                ),

                const SizedBox(height: 36),

                // 🟣 BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 58,

                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitFeedback,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E1B4F),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),

                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.submitFeedback,
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
      ),
    );
  }
}
