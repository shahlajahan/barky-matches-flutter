import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  int rating = 0;

  String category = "general_feedback";

  final TextEditingController messageController =
      TextEditingController();

  bool isSubmitting = false;

  Future<void> submitFeedback() async {

  if (rating == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please select rating"),
      ),
    );
    return;
  }

  setState(() {
    isSubmitting = true;
  });

  try {

    final uid = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection("user_feedback")
        .add({

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
      const SnackBar(
        content: Text(
          "Feedback submitted successfully",
        ),
      ),
    );

  } catch (e) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Submission failed: $e"),
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
              isSelected
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: const Color(0xFFFFC107),
              size: 34,
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,

      prefixIcon: icon != null
          ? Icon(
              icon,
              color: const Color(0xFF9E1B4F),
            )
          : null,

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),

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
        borderSide: const BorderSide(
          color: Color(0xFF9E1B4F),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () {
    FocusScope.of(context).unfocus();
  },

  child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            120,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🟣 HEADER CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9E1B4F),
                      Color(0xFFE91E63),
                    ],
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFFC107),
                      size: 34,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Send Feedback",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFC107),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Help us improve PetSupo with your feedback, ideas, and suggestions.",
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
                      "Rate your experience",
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
                "Feedback Category",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: category,

                decoration: _inputDecoration(
                  label: "Select category",
                  icon: Icons.category_rounded,
                ),

                dropdownColor: Colors.white,

                items: const [
                  DropdownMenuItem(
                    value: "general_feedback",
                    child: Text("General Feedback"),
                  ),

                  DropdownMenuItem(
                    value: "bug",
                    child: Text("Bug Report"),
                  ),

                  DropdownMenuItem(
                    value: "feature_request",
                    child: Text("Feature Request"),
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
                "Your Message",
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
                  onPressed: isSubmitting
                      ? null
                      : submitFeedback,

                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF9E1B4F),

                    foregroundColor: Colors.white,

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
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
                          "Submit Feedback",
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