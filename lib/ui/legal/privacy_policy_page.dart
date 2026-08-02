import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.emailAppUnavailable),
        ),
      );
    }
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.emailCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: Text(l10n.privacyPolicyLabel),
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
                l10n.privacyPolicyContent,
                style: GoogleFonts.poppins(fontSize: 14, height: 1.6),
              ),

              const SizedBox(height: 24),

              /// 🔥 CONTACT CARD
              Text(
                l10n.privacyContactTitle,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                l10n.privacyContactPrompt,
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
                    const Icon(LucideIcons.mail, color: Color(0xFF9E1B4F)),

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
                l10n.privacyResponseTime,
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
