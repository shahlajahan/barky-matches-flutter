// lib/admin/moderation/widgets/moderation_action_bar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ModerationActionBar extends StatelessWidget {
  final String caseId;
  final String targetId;
  final String type;

  const ModerationActionBar({
    super.key,
    required this.caseId,
    required this.targetId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const Text(
              "Admin Actions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _reviewCase("confirm_violation"),
              child: const Text("Confirm Violation"),
            ),

            ElevatedButton(
              onPressed: () => _reviewCase("clean"),
              child: const Text("Mark Clean"),
            ),

            ElevatedButton(
              onPressed: () => _reviewCase("suspend"),
              child: const Text("Suspend"),
            ),

            ElevatedButton(
              onPressed: () => _reviewCase("restore"),
              child: const Text("Restore"),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _reviewCase(String action) async {

    final callable =
        FirebaseFunctions.instanceFor(region: 'europe-west3')
            .httpsCallable("reviewModerationCase");

    await callable.call({
      "caseId": caseId,
      "action": action,
      "reason": "",
    });
  }
}