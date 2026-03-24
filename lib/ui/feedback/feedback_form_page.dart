import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {

  int rating = 0;
  String category = "general_feedback";
  final TextEditingController messageController = TextEditingController();

  bool isSubmitting = false;

  Future<void> submitFeedback() async {

    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select rating")),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

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

    Navigator.pop(context);

  }

  Widget buildStars() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {

        final starIndex = index + 1;

        return IconButton(
          icon: Icon(
            rating >= starIndex
                ? Icons.star
                : Icons.star_border,
            color: Colors.orange,
            size: 32,
          ),
          onPressed: () {

            setState(() {
              rating = starIndex;
            });

          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Feedback"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            const Text(
              "Rate BarkyMatches",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 10),

            buildStars(),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: category,
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

            const SizedBox(height: 20),

            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Message",
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(

                onPressed: isSubmitting
                    ? null
                    : submitFeedback,

                child: const Text("Submit Feedback"),
              ),
            )

          ],
        ),
      ),
    );
  }
}