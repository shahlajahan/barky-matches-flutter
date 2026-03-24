import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfferDetailsPage extends StatelessWidget {
  final String? title;
  final int? discount;
  final String? code;
  final String? provider;
  final String? imageUrl;

  const OfferDetailsPage({
    super.key,
    this.title,
    this.discount,
    this.code,
    this.provider,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107), // 🔥 gold background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Offer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 DISCOUNT BIG
            Text(
              "${discount ?? 0}%",
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "OFF",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 TITLE
            Text(
              title ?? "Special Offer",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            // 🔥 PROVIDER
            Text(
              provider ?? "",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 CODE (premium style, بدون باکس سنگین)
            Row(
              children: [
                Text(
                  "Use code:",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  code ?? "---",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 🔥 CTA BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 🔥 copy code or redirect
                  if (code != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Code copied: $code")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Use This Offer",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 IMAGE (optional پایین)
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}