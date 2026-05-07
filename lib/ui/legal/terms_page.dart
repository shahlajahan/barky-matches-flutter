import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  final String email = "support@petsupo.com";

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Terms Inquiry - PetSupo',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email copied")),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text("Terms of Service"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// INTRO
              Text(
                "By using PetSupo, you agree to the following terms:",
                style: GoogleFonts.poppins(fontSize: 14),
              ),

              const SizedBox(height: 20),

              /// SECTIONS
              _section(
                "1. Platform Role",
                "PetSupo acts solely as a digital intermediary and does not provide veterinary, pet care, or transportation services directly.",
              ),

              _section(
                "2. User Responsibility",
                "Users are responsible for the accuracy of the information they provide, their interactions with others, and any agreements made outside the platform.",
              ),

              _section(
                "3. No Liability",
                "PetSupo is not liable for injuries, damages, disputes between users, or services provided by third-party businesses.",
              ),

              _section(
                "4. Account Usage",
                "Users must not provide false information, engage in illegal activities, or harm other users.",
              ),

              _section(
                "5. Data Protection (KVKK)",
                "User data is processed in accordance with Turkish Personal Data Protection Law (KVKK No. 6698) and stored securely.",
              ),

              _section(
                "6. Modifications",
                "PetSupo reserves the right to update these terms at any time. Continued use of the app means acceptance of the updated terms.",
              ),

              const SizedBox(height: 10),

              /// 🔥 CONTACT
              Text(
                "7. Contact",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.mail,
                      color: Color(0xFF9E1B4F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _launchEmail(context),
                        child: Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 18),
                      onPressed: () => _copyEmail(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "We aim to respond within a reasonable timeframe.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}