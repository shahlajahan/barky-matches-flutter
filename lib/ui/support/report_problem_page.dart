import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String category = "Bug";
  File? screenshot;
  bool loading = false;

  final picker = ImagePicker();

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    setState(() {
      screenshot = File(file.path);
    });
  }

  Future<String?> uploadScreenshot(String uid) async {
    if (screenshot == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("complaints")
          .child(uid)
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

      await ref.putFile(screenshot!);

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("🔥 Screenshot upload failed: $e");
      return null;
    }
  }

  Future<void> submitReport() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) throw Exception("User not logged in");

      final screenshotUrl = await uploadScreenshot(uid);

      await FirebaseFirestore.instance.collection("complaints").add({
        "userId": uid,
        "createdBy": uid,

        "title": titleController.text.trim(),
        "description": descriptionController.text.trim(),

        "category": category,

        "status": "open",
        "severity": "medium",
        "priority": "normal",

        "targetType": "app",
        "targetId": null,

        "screenshotUrl": screenshotUrl,

        "evidenceCount": screenshotUrl == null ? 0 : 1,
        "messageCount": 1,

        "isArchived": false,

        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      titleController.clear();
      descriptionController.clear();

      setState(() {
        category = "Bug";
        screenshot = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report submitted successfully")),
      );
    } catch (e) {
      debugPrint("🔥 submitReport error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to send report: $e")));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: const Color(0xFF9E1B4F)),
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

  Widget buildScreenshotPreview() {
    if (screenshot == null) {
      return GestureDetector(
        onTap: pickImage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF9E1B4F).withOpacity(.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  LucideIcons.imagePlus,
                  color: Color(0xFF9E1B4F),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Attach screenshot",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9E1B4F),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Optional, but helps us understand the issue faster.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              screenshot!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  screenshot = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9E1B4F),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF2F5),

      child: Stack(
        children: [
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTap: () {
                FocusScope.of(context).unfocus();
              },

              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
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
                            LucideIcons.bug,
                            color: Color(0xFFFFC107),
                            size: 36,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            "Report a Problem",

                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFC107),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "Tell us what went wrong. Your report helps us improve PetSupo.",

                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(.92),

                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    _sectionLabel(
                      title: "Category",
                      icon: LucideIcons.listFilter,
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: category,

                      dropdownColor: Colors.white,

                      decoration: _inputDecoration(
                        label: "Select category",
                        icon: LucideIcons.tag,
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: "Bug",
                          child: Text("Bug report"),
                        ),

                        DropdownMenuItem(
                          value: "Abuse",
                          child: Text("Abuse / harassment"),
                        ),

                        DropdownMenuItem(
                          value: "Incorrect",
                          child: Text("Incorrect information"),
                        ),

                        DropdownMenuItem(
                          value: "Payment",
                          child: Text("Payment issue"),
                        ),

                        DropdownMenuItem(value: "Other", child: Text("Other")),
                      ],

                      onChanged: (v) {
                        setState(() {
                          category = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionLabel(title: "Title", icon: LucideIcons.type),

                    const SizedBox(height: 10),

                    TextField(
                      controller: titleController,

                      decoration: _inputDecoration(
                        label: "Briefly describe the problem",

                        icon: LucideIcons.alertCircle,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _sectionLabel(
                      title: "Description",
                      icon: LucideIcons.fileText,
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: descriptionController,
                      maxLines: 6,

                      decoration: _inputDecoration(
                        label: "Add more details...",
                        icon: LucideIcons.messageSquare,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _sectionLabel(title: "Screenshot", icon: LucideIcons.image),

                    const SizedBox(height: 10),

                    buildScreenshotPreview(),

                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E1B4F),

                          foregroundColor: Colors.white,

                          disabledBackgroundColor: Colors.grey.shade300,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),

                        onPressed: loading ? null : submitReport,

                        child: loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,

                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  const Icon(LucideIcons.send, size: 18),

                                  const SizedBox(width: 10),

                                  Text(
                                    "Submit Report",

                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
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
          ),

          if (loading)
            Container(
              color: Colors.black26,

              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF9E1B4F)),
              ),
            ),
        ],
      ),
    );
  }
}
