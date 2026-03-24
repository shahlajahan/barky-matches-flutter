import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

class SuggestClinicSheet extends StatelessWidget {
  final String vetName;

  const SuggestClinicSheet({
    super.key,
    required this.vetName,
  });

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;

    if (box == null) return;

    await Share.share(
      'Hi 👋\n\n'
      'BarkyMatches helps pet owners find and book veterinary appointments easily 🐶🐾\n\n'
      'We would love to see *$vetName* join BarkyMatches!\n\n'
      '👉 https://barkymatches.com',
      sharePositionOrigin:
          box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Icon(
            Icons.pets,
            size: 40,
            color: Color(0xFFFFC107),
          ),

          const SizedBox(height: 16),

          const Text(
            'Help us grow BarkyMatches',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Suggest $vetName to join BarkyMatches and help pet owners book appointments more easily.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final appState = context.read<AppState>();
                final userId = appState.currentUserId;
                final username = appState.username ?? 'User';

                // 1️⃣ Save to Firestore
                await FirebaseFirestore.instance
                    .collection('clinic_suggestions')
                    .add({
                  'vetName': vetName,
                  'suggestedByUserId': userId,
                  'suggestedByUsername': username,
                  'channel': 'share',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // 2️⃣ Share (iPad-safe)
                await _share(context);

                Navigator.pop(context);
              },
              child: const Text(
                'Share Invitation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}