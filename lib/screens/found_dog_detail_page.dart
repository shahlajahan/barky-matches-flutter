import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/found_dog.dart';

class FoundDogDetailPage extends StatelessWidget {
  final FoundDog foundDog;

  const FoundDogDetailPage({super.key, required this.foundDog});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Found Dog Details',
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFC107), // زرد
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFC107)), // زرد برای آیکون‌ها
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: foundDog.isClaimed ? Colors.pink[100] : Colors.pink[50], // تغییر به صورتی روشن
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.pets, size: 50, color: Color(0xFFFFC107)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Name: ${foundDog.name}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Breed: ${foundDog.breed}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 18,
                    ),
                  ),
                  if (foundDog.color != null)
                    Text(
                      'Color: ${foundDog.color}',
                      style: GoogleFonts.poppins(
                        color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                        fontSize: 18,
                      ),
                    ),
                  if (foundDog.weight != null)
                    Text(
                      'Weight: ${foundDog.weight} kg',
                      style: GoogleFonts.poppins(
                        color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                        fontSize: 18,
                      ),
                    ),
                  if (foundDog.collarType != null)
                    Text(
                      'Collar Type: ${foundDog.collarType}',
                      style: GoogleFonts.poppins(
                        color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                        fontSize: 18,
                      ),
                    ),
                  if (foundDog.clothingColor != null)
                    Text(
                      'Clothing Color: ${foundDog.clothingColor}',
                      style: GoogleFonts.poppins(
                        color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                        fontSize: 18,
                      ),
                    ),
                  Text(
                    'Found Location: ${foundDog.foundLocation}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Contact Info: ${foundDog.contactInfo}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 18,
                    ),
                  ),
                  if (foundDog.description != null && foundDog.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Description: ${foundDog.description}',
                        style: GoogleFonts.poppins(
                          color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Reported by: ${foundDog.reportedBy}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Reported at: ${foundDog.reportedAt.toLocal().toString().split('.')[0]}',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    foundDog.isClaimed ? 'Status: Claimed' : 'Status: Not Claimed',
                    style: GoogleFonts.poppins(
                      color: foundDog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107), // زرد یا صورتی ملایم
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}