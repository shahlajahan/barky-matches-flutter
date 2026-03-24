import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackItem extends StatelessWidget {

  final DocumentSnapshot doc;
  final VoidCallback onTap;

  const FeedbackItem({
    super.key,
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    final data = doc.data() as Map<String, dynamic>;

    return ListTile(
      onTap: onTap,
      leading: Text("⭐${data["rating"]}"),
      title: Text(data["category"] ?? ""),
      subtitle: Text(data["message"] ?? ""),
      trailing: Text(data["status"] ?? ""),
    );

  }
}