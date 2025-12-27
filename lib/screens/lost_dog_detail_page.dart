import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lost_dog.dart';

class LostDogDetailPage extends StatelessWidget {
  final LostDog lostDog;

  const LostDogDetailPage({super.key, required this.lostDog});

  @override
  Widget build(BuildContext context) {
    // چک کردن اعتبار lostDog
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lost Dog Details',
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFC107),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFC107)),
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
            color: lostDog.isFound ? Colors.pink[100] : Colors.pink[50],
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
                    'Name: ${lostDog.name}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Breed: ${lostDog.breed}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 18,
                    ),
                  ),
                  if (lostDog.color != null)
                    Text(
                      'Color: ${lostDog.color}',
                      style: GoogleFonts.poppins(
                        color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                        fontSize: 18,
                      ),
                    ),
                  if (lostDog.weight != null)
                    Text(
                      'Weight: ${lostDog.weight} kg',
                      style: GoogleFonts.poppins(
                        color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                        fontSize: 18,
                      ),
                    ),
                  if (lostDog.collarType != null)
                    Text(
                      'Collar Type: ${lostDog.collarType}',
                      style: GoogleFonts.poppins(
                        color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                        fontSize: 18,
                      ),
                    ),
                  if (lostDog.clothingColor != null)
                    Text(
                      'Clothing Color: ${lostDog.clothingColor}',
                      style: GoogleFonts.poppins(
                        color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                        fontSize: 18,
                      ),
                    ),
                  Text(
                    'Lost Location: ${lostDog.lostLocation}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Contact Info: ${lostDog.contactInfo}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 18,
                    ),
                  ),
                  if (lostDog.description != null && lostDog.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Description: ${lostDog.description}',
                        style: GoogleFonts.poppins(
                          color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Reported by: ${lostDog.reportedBy}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Reported at: ${lostDog.reportedAt.toLocal().toString().split('.')[0]}',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lostDog.isFound ? 'Status: Found' : 'Status: Not Found',
                    style: GoogleFonts.poppins(
                      color: lostDog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
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