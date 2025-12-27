import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';
import 'home_page.dart';
import 'vet_page.dart';
import 'adoption_page.dart';
import 'dog_park_page.dart';
import 'app_state.dart' as MyAppState;
import 'auth_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'offers_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'main.dart'; // برای دسترسی به MyApp

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _postFirstFrameInit());
    OffersManager.loadOffers();
  }

  Future<void> _postFirstFrameInit() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      setState(() => _isInitialized = true);
      print('WelcomePage - Using dogs from AppState: ${MyAppState.AppState.of(context).dogsList.length} dogs');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appState = MyAppState.AppState.of(context);
    return Scaffold(
      body: _isInitialized
          ? RepaintBoundary(
              child: Stack(
                children: [
                  const _BackgroundGradient(),
                  SafeArea(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 40),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  localizations.welcomeTo,
                                  style: GoogleFonts.dancingScript(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  localizations.barkyMatches,
                                  style: GoogleFonts.dancingScript(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FutureBuilder(
                                  future: OffersManager.loadOffers(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Center(child: Text(localizations.errorLoadingOffers(snapshot.error.toString())));
                                    }
                                    return OffersManager.buildOffersSection(false);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              localizations.appFeatures,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 200,
                              child: RepaintBoundary(
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  cacheExtent: 1000, // بهینه‌سازی رندر
                                  itemCount: 6,
                                  itemBuilder: (context, index) {
                                    switch (index) {
                                      case 0:
                                        return _buildServiceCard(
                                          icon: Icons.pets,
                                          title: localizations.playmateService,
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(localizations.signInToAccessPlaymate)),
                                            );
                                          },
                                        );
                                      case 1:
                                        return _buildServiceCard(
                                          icon: Icons.local_hospital,
                                          title: localizations.vetServices,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const VetPage(),
                                              ),
                                            );
                                          },
                                        );
                                      case 2:
                                        return _buildServiceCard(
                                          icon: Icons.favorite,
                                          title: localizations.adoptionCenter,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AdoptionPage(
                                                  dogs: appState.dogsList,
                                                  favoriteDogs: appState.favoriteDogsNotifier.value,
                                                  onToggleFavorite: appState.onToggleFavorite,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      case 3:
                                        return _buildServiceCard(
                                          icon: Icons.school,
                                          title: localizations.dogTraining,
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(localizations.dogTrainingComingSoon)),
                                            );
                                          },
                                        );
                                      case 4:
                                        return _buildServiceCard(
                                          icon: Icons.park,
                                          title: localizations.dogPark,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const DogParkPage(),
                                              ),
                                            );
                                          },
                                        );
                                      case 5:
                                        return _buildServiceCard(
                                          icon: Icons.group,
                                          title: localizations.findFriends,
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(localizations.signInToFindFriends)),
                                            );
                                          },
                                          customIcon: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.pets,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 5),
                                              Icon(
                                                Icons.pets,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                            ],
                                          ),
                                        );
                                      default:
                                        return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ),
                            ),
                            // فلش به سمت راست برای نشان دادن قابلیت اسکرول
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0, top: 5.0),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Icon(
                              Icons.pets,
                              size: 120,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 10),
                            // اضافه کردن گزینه انتخاب زبان
                            FutureBuilder<String>(
                              future: _loadSavedLanguage(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }
                                final selectedLanguage = snapshot.data ?? 'en';
                                return DropdownButton<String>(
                                  value: selectedLanguage,
                                  items: <String>['en', 'fa', 'tr'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value == 'en' ? 'English' : value == 'fa' ? 'فارسی' : 'Türkçe',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      _saveLanguage(newValue);
                                      MyApp.setLocale(context, Locale(newValue));
                                    }
                                  },
                                  dropdownColor: Colors.pink.withOpacity(0.9),
                                  iconEnabledColor: Colors.white,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _SignInButton(
                                    onDogAdded: (newDog) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HomePage(
                                            dogsList: appState.dogsList,
                                            favoriteDogs: appState.favoriteDogsNotifier.value,
                                            onToggleFavorite: appState.onToggleFavorite,
                                          ),
                                        ),
                                      );
                                    },
                                    favoriteDogs: appState.favoriteDogsNotifier.value,
                                    onToggleFavorite: appState.onToggleFavorite,
                                  ),
                                  _SignUpButton(
                                    onDogAdded: (newDog) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HomePage(
                                            dogsList: appState.dogsList,
                                            favoriteDogs: appState.favoriteDogsNotifier.value,
                                            onToggleFavorite: appState.onToggleFavorite,
                                          ),
                                        ),
                                      );
                                    },
                                    favoriteDogs: appState.favoriteDogsNotifier.value,
                                    onToggleFavorite: appState.onToggleFavorite,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Future<String> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('language') ?? 'en';
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    MyApp.setLocale(context, Locale(language));
  }
}

class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink, Colors.pinkAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final Function(Dog) onDogAdded;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const _SignInButton({
    required this.onDogAdded,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthPage(
              isLogin: true,
              onDogAdded: onDogAdded,
              dogsList: MyAppState.AppState.of(context).dogsList,
              favoriteDogs: MyAppState.AppState.of(context).favoriteDogsNotifier.value,
              onToggleFavorite: MyAppState.AppState.of(context).onToggleFavorite,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        localizations.signInButton,
        style: GoogleFonts.poppins(fontSize: 18),
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  final Function(Dog) onDogAdded;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const _SignUpButton({
    required this.onDogAdded,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthPage(
              isLogin: false,
              onDogAdded: onDogAdded,
              dogsList: MyAppState.AppState.of(context).dogsList,
              favoriteDogs: MyAppState.AppState.of(context).favoriteDogsNotifier.value,
              onToggleFavorite: MyAppState.AppState.of(context).onToggleFavorite,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        localizations.signUpButton,
        style: GoogleFonts.poppins(fontSize: 18),
      ),
    );
  }
}

Widget _buildServiceCard({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Widget? customIcon,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          customIcon ??
              Icon(
                icon,
                size: 30,
                color: Colors.red,
              ),
          const SizedBox(height: 5),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}