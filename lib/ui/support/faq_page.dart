import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqItems = [
      _faq(
        "What is PetSupo?",
        "PetSupo is a platform that connects pet owners and helps them find suitable playmates, services, and resources for their pets.",
      ),
      _faq(
        "How can I find a playmate for my dog?",
        "Go to the Playmate section and use filters such as breed, age, and location to find suitable matches.",
      ),
      _faq(
        "Is PetSupo free to use?",
        "Basic features are free. Premium features may be available for enhanced visibility and additional benefits.",
      ),
      _faq(
        "Is it safe to meet other users?",
        "Users interact at their own responsibility. We recommend meeting in public places and taking necessary precautions.",
      ),
      _faq(
        "What should I do if I encounter a problem?",
        "You can report issues directly through the 'Report Problem' section in the app.",
      ),
      _faq(
        "How does location work?",
        "Location is used to show nearby pets, services, and matches. You can control location permissions from your device settings.",
      ),
      _faq(
        "How is my data protected?",
        "Your data is processed in accordance with applicable data protection laws, including KVKK. Please refer to our Privacy Policy for more details.",
      ),
      _faq(
        "Can I delete my account?",
        "Yes. You can request account deletion through the app or contact support for assistance.",
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("FAQ"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          final item = faqItems[index];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              leading: const Icon(LucideIcons.helpCircle),
              title: Text(
                item.question,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    item.answer,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _FAQItem _faq(String q, String a) {
    return _FAQItem(question: q, answer: a);
  }
}

class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({
    required this.question,
    required this.answer,
  });
}