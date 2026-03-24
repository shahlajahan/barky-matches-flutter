import 'package:flutter/material.dart';
import 'dog.dart';
import 'auth_page.dart';

import 'vet_page.dart';
import 'adoption_page.dart';
import 'dog_park_page.dart';
import 'add_dog_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'package:barky_matches_fixed/home_gate.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
 // اضافه کردن برای محلی‌سازی

class Greeting extends StatefulWidget {
  final String username;
  final Function(Dog)? onDogAdded;
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const Greeting({
    super.key,
    required this.username,
    required this.onDogAdded,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  void _addDog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDogPage(
          onDogAdded: widget.onDogAdded,
          favoriteDogs: widget.favoriteDogs,
          onToggleFavorite: widget.onToggleFavorite,
        ),
      ),
    );
  }

  void _continueAsGuest() {
    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => const HomeGate(),
  ),
);

  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // دسترسی به متن‌های محلی‌سازی‌شده
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle, // به جای 'Playful Dogs' (استفاده از کلید موجود)
          style: GoogleFonts.dancingScript(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.pink[300],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.username.isEmpty ? l10n.welcomeToBarkyMatches : l10n.welcomeBack(widget.username), // به جای 'Welcome to Playful Dogs!' و 'Welcome, ${widget.username}!'
                  style: GoogleFonts.dancingScript(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.appFeaturesMessage, // به جای 'Explore a world of fun for your furry friends!'
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 200,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildServiceCard(
                        context,
                        icon: Icons.pets,
                        title: l10n.playmateService, // به جای 'Playmate'
                        onTap: () {
                          Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => const HomeGate(),
  ),
);

                        },
                      ),
                      _buildServiceCard(
  context,
  icon: Icons.local_hospital,
  title: l10n.vetServices,
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.vetServicesAvailableAfterLogin),
      ),
    );
  },
),

                      _buildServiceCard(
                        context,
                        icon: Icons.favorite,
                        title: l10n.adoptionService, // به جای 'Adoption Center'
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdoptionPage(
                                dogs: widget.dogsList,
                                favoriteDogs: widget.favoriteDogs,
                                onToggleFavorite: widget.onToggleFavorite,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildServiceCard(
                        context,
                        icon: Icons.school,
                        title: l10n.dogTrainingService, // به جای 'Dog Training'
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.dogTrainingComingSoon)), // به جای 'Dog Training Coming Soon!'
                          );
                        },
                      ),
                      _buildServiceCard(
                        context,
                        icon: Icons.park,
                        title: l10n.dogParkService, // به جای 'Dog Park'
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DogParkPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthPage(
                          isLogin: true,
                          onDogAdded: widget.onDogAdded,
                          dogsList: widget.dogsList,
                          favoriteDogs: widget.favoriteDogs,
                          onToggleFavorite: widget.onToggleFavorite,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    l10n.signInButton, // به جای 'Sign In'
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthPage(
                          isLogin: false,
                          onDogAdded: widget.onDogAdded,
                          dogsList: widget.dogsList,
                          favoriteDogs: widget.favoriteDogs,
                          onToggleFavorite: widget.onToggleFavorite,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    l10n.signUpButton, // به جای 'Sign Up'
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _continueAsGuest,
                  child: Text(
                    l10n.continueAsGuest, // به جای 'Continue as Guest'
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: Colors.pinkAccent,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}