import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aboutUsTitle),
        backgroundColor: const Color(0xFF9E1B4F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context)!.aboutUsContent,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}
