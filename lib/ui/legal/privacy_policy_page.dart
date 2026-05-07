import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  final String email = "support@petsupo.com";

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Privacy Inquiry - PetSupo',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email app")),
      );
    }
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text("Privacy Policy"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 📄 TEXT
              Text(
                """
PetSupo respects your privacy and is committed to protecting your personal data.

1. Data We Collect
We may collect the following data:
• Personal information (name, email, phone number)
• Location data (for matching and services)
• Pet-related information
• Media uploads (photos/videos)
• Device and notification data (including FCM token)

2. How We Use Your Data
Your data is used to:
• Provide and operate our services
• Enable user matching and communication
• Improve app performance and user experience
• Send notifications (only with your permission)

3. Data Sharing
We do NOT sell your personal data.
Your data may be shared only:
• With trusted service providers (e.g. Firebase, cloud infrastructure)
• When required by law or legal processes

4. Data Storage & Security
Your data is securely stored on servers located in Europe.
We apply appropriate technical and organizational measures to protect your data.

5. Data Retention
We retain your data only as long as necessary to provide our services.
Users may request deletion of their data at any time.

6. Your Rights (KVKK & GDPR)
You have the right to:
• Access your personal data
• Request correction or deletion
• Withdraw consent at any time
• Request data portability

7. Account Deletion
You can request deletion of your account and all associated data by contacting us.
We will process deletion requests in accordance with applicable laws.

8. Children's Privacy
PetSupo is not intended for children under the age of 13.
We do not knowingly collect data from children.

9. Changes to This Policy
We may update this Privacy Policy from time to time.
Users will be notified of significant changes.

10. Contact
If you have any questions about this Privacy Policy or your data, please contact us:
""",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              /// 🔥 CONTACT CARD
              Text(
                "7. Contact",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "If you have any questions about this Privacy Policy or your data, please contact us:",
                style: GoogleFonts.poppins(fontSize: 13),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [

                    /// 📧 ICON
                    const Icon(
                      LucideIcons.mail,
                      color: Color(0xFF9E1B4F),
                    ),

                    const SizedBox(width: 10),

                    /// 📧 EMAIL (CLICKABLE)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _launchEmail(context),
                        child: Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    /// 📋 COPY BUTTON
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 18),
                      onPressed: () => _copyEmail(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "We will respond as soon as possible.",
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