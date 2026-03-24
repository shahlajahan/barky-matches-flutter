import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeedbackDetailPage extends StatelessWidget {

  final DocumentSnapshot doc;

  const AdminFeedbackDetailPage({
    super.key,
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {

    final data = doc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Feedback Detail"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("Rating: ${data["rating"]}"),
            const SizedBox(height: 10),

            Text("Category: ${data["category"]}"),
            const SizedBox(height: 10),

            Text("Context: ${data["context"]}"),
            const SizedBox(height: 20),

            const Text("Message"),
            const SizedBox(height: 5),

            Text(data["message"] ?? ""),

            const SizedBox(height: 30),

            Text("Status: ${data["status"]}")

          ],
        ),
      ),
    );
  }
}