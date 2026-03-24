import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a title"),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) throw Exception("User not logged in");

      String? screenshotUrl =
          await uploadScreenshot(uid);

      await FirebaseFirestore.instance
          .collection("complaints")
          .add({

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

      Navigator.pop(context);

    } catch (e) {

      debugPrint("🔥 submitReport error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send report: $e"),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget buildScreenshotPreview() {

    if (screenshot == null) return const SizedBox();

    return Stack(
      children: [

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            screenshot!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),

        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                screenshot = null;
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
Widget build(BuildContext context) {

  return Scaffold(

    appBar: AppBar(
      title: const Text("Report a Problem"),
      backgroundColor: AppTheme.primary,
      elevation: 0,
    ),

    body: Stack(

      children: [

        SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text(
                "Category",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField(

                value: category,

                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

                  DropdownMenuItem(
                    value: "Other",
                    child: Text("Other"),
                  ),
                ],

                onChanged: (v) {
                  setState(() {
                    category = v!;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              buildScreenshotPreview(),

              const SizedBox(height: 10),

              TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Attach screenshot"),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFFFFC107),

                    foregroundColor: Colors.black,

                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  onPressed: loading ? null : submitReport,

                  child: const Text(
                    "Submit",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

            ],
          ),
        ),

        /// Loading Overlay
        if (loading)
          Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          )
      ],
    ),
  );
}
}