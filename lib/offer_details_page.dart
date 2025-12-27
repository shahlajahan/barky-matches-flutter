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
      appBar: AppBar(
        title: const Text('Offer Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey,
                    child: const Center(child: Text('Image not available')),
                  );
                },
              ),
            const SizedBox(height: 10),
            Text(
              'Title: ${title ?? 'N/A'}',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Discount: ${discount ?? 0}%',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            Text(
              'Code: ${code ?? 'N/A'}',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            Text(
              'Provider: ${provider ?? 'N/A'}',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}