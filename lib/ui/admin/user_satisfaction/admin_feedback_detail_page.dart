import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdminFeedbackDetailPage extends StatelessWidget {
  final DocumentSnapshot doc;

  const AdminFeedbackDetailPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.feedbackDetail),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.ratingValue('${data["rating"]}')),
            const SizedBox(height: 10),

            Text(
              AppLocalizations.of(context)!.categoryValue('${data["category"]}'),
            ),
            const SizedBox(height: 10),

            Text(
              AppLocalizations.of(context)!.contextValue('${data["context"]}'),
            ),
            const SizedBox(height: 20),

            Text(AppLocalizations.of(context)!.messageLabel),
            const SizedBox(height: 5),

            Text(data["message"] ?? ""),

            const SizedBox(height: 30),

            Text(
              AppLocalizations.of(context)!.statusValue('${data["status"]}'),
            ),
          ],
        ),
      ),
    );
  }
}
