import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("About Us"),
        backgroundColor: const Color(0xFF9E1B4F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          """
PetSupo is a digital platform designed to connect pet owners and improve the social lives of pets.

The application enables users to find suitable playmates for their dogs, discover nearby veterinary services, and access pet-related businesses such as pet shops, groomers, and pet hotels.

PetSupo does not act as a service provider but as a facilitator between users and third-party services. Users are responsible for their interactions and decisions made through the platform.

Our mission is to provide a safe, efficient, and user-friendly environment for pet owners worldwide.
""",
          style: GoogleFonts.poppins(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}