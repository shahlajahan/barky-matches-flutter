import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';
import 'home_page.dart';
import 'vet_page.dart';
import 'adoption_page.dart';
import 'dog_park_page.dart';
//import 'app_state.dart' as MyAppState;
import 'auth_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'offers_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'main.dart'; // برای دسترسی به MyApp
import 'package:barky_matches_fixed/ui/welcome/preview_dogs_section.dart';
import 'theme/app_theme.dart';
import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
//import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/home_gate.dart';
import 'package:flutter/foundation.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  bool _isLoading = false;
  final GlobalKey _offerKey = GlobalKey();
double _offerRealHeight = 0;
AnimationController? _pulseController;
Animation<double>? _pulseAnimation;

  @override
void initState() {
  super.initState();

  _initPage(); // 🔥 مهم

  // 🔥 PULSE INIT
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  _pulseAnimation = Tween<double>(
    begin: 1.18,
    end: 1.26,
  ).animate(
    CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ),
  );
}

Future<void> _initPage() async {
  await OffersManager.loadOffersOnce(); // ⬅️ منتظر بمون

  if (!mounted) return;

  setState(() {
    _isInitialized = true; // ⬅️ همزمان UI رو آپدیت کن
  });
}

Widget _buildQuickAction({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTheme.body(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
  @override
void dispose() {
  _pulseController?.dispose();
  super.dispose();
}
void _measureOffer() {
  final offerContext = _offerKey.currentContext;
  if (offerContext == null) return;

  final box = offerContext.findRenderObject() as RenderBox?;
  if (box == null) return;

  final height = box.size.height;

  if (height != _offerRealHeight) {
    setState(() {
      _offerRealHeight = height;
    });
  }
}
 @override
Widget build(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;
  final appState = context.watch<app.AppState>();

  final previewDogs = appState.allDogs.take(3).toList();
  WidgetsBinding.instance.addPostFrameCallback((_) {
  _measureOffer();
});

  
  return Scaffold(
    backgroundColor: AppTheme.bg,
    body: Stack(
      children: [

        // 🟢 MAIN CONTENT
        _isInitialized
            ? SafeArea(
                top: true,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 8),

                      // 👋 HEADER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Welcome back 👋",
                          style: AppTheme.h1(),
                        ),
                      ),

                      const SizedBox(height: 9),

                      // 🎁 OFFERS
                      Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    children: [

      // 🎁 OFFER
      Expanded(
  child: AspectRatio(
    aspectRatio: 1.6,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),

        // 🔥 GOLD GRADIENT
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD54F), // light gold
            Color(0xFFFFC107), // main gold
            Color(0xFFFFA000), // deep gold
          ],
        ),

        // 🔥 SUBTLE GLOW + DEPTH
        boxShadow: [
          // glow
          BoxShadow(
            color: Color(0xFFFFC107).withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),

          // depth shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [

            // ✨ LIGHT REFLECTION (خیلی subtle)
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),

            // 🎁 CONTENT
            OffersManager.buildOffersSection(context, null),
          ],
        ),
      ),
    ),
  ),
),

      const SizedBox(width: 12),

      // 🐾 LOGO
      Expanded(
  child: AspectRatio(
    aspectRatio: 1.6,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center( // 🔥 مهم
        child: _pulseAnimation == null
            ? Image.asset(
                "assets/image/logo.png",
                height: 90,
              )
            : AnimatedBuilder(
                animation: _pulseAnimation!,
                builder: (context, child) {
                 

                  return Transform.scale(
                    scale: _pulseAnimation!.value,
                    child: child,
                  );
                },
                child: Image.asset(
                  "assets/image/logo.png",
                  height: 90, // 🔥 خیلی مهم → بدون این دیده نمیشه
                ),
              ),
      ),
    ),
  ),
),
    ],
  ),
),
                      const SizedBox(height: 8),

                      PreviewDogsSection(
                        previewDogs: previewDogs,
                      ),

                      const SizedBox(height: 8),

                      // ⚡ QUICK ACTIONS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          localizations.appFeatures,
                          style: AppTheme.h1().copyWith(
                            color: const Color(0xFF9E1B4F),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [

                            _buildQuickAction(
                              icon: Icons.pets,
                              title: localizations.playmateService,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(localizations.signInToAccessPlaymate)),
                                );
                              },
                            ),

                            _buildQuickAction(
                              icon: Icons.local_hospital,
                              title: localizations.vetServices,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(localizations.signInToAccessPlaymate)),
                                );
                              },
                            ),

                            // 🔥 ADOPTION
                            _buildQuickAction(
                              icon: Icons.favorite,
                              title: localizations.adoptionCenter,
                              onTap: () async {
                                debugPrint("🟡 Welcome → set tab = NavTab.adoption");

                                setState(() {
                                  _isLoading = true;
                                });

                                final appState = context.read<app.AppState>();

                                appState.setGuestUser();
                                appState.setCurrentTab(NavTab.adoption);

                                await Future.delayed(const Duration(milliseconds: 300));

                                if (!mounted) return;

                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const HomeGate()),
                                  (route) => false,
                                );
                              },
                            ),

                            _buildQuickAction(
                              icon: Icons.school,
                              title: localizations.dogTraining,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(localizations.dogTrainingComingSoon)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🌍 LANGUAGE
                      Center(
                        child: FutureBuilder<String>(
                          future: _loadSavedLanguage(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();

                            final selectedLanguage = snapshot.data ?? 'en';

                            return DropdownButton<String>(
                              value: selectedLanguage,
                              items: ['en', 'fa', 'tr'].map((value) {
                                return DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value == 'en'
                                        ? 'English'
                                        : value == 'fa'
                                            ? 'فارسی'
                                            : 'Türkçe',
                                    style: AppTheme.body(),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _saveLanguage(value);
                                  context.read<app.AppState>().setLocale(value);
                                }
                              },
                              dropdownColor: Colors.white,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🔐 AUTH BUTTONS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SignInButton(
                                onDogAdded: (_) {
                                  Navigator.pushReplacementNamed(context, '/home');
                                },
                                favoriteDogs: appState.favoriteDogsNotifier.value,
                                onToggleFavorite: appState.onToggleFavorite,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SignUpButton(
                                onDogAdded: (_) {
                                  Navigator.pushReplacementNamed(context, '/home');
                                },
                                favoriteDogs: appState.favoriteDogsNotifier.value,
                                onToggleFavorite: appState.onToggleFavorite,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),


        // 🔥 SPINNER OVERLAY
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.6),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    ),
  );
}
  Future<String> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('language') ?? 'en';
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    context.watch<app.AppState>().setLocale(language);
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
              //dogs: AppState.of(context).allDogs,

              favoriteDogs: context.watch<app.AppState>().favoriteDogsNotifier.value,
              onToggleFavorite: context.watch<app.AppState>().onToggleFavorite,
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
              //dogs: AppState.of(context).allDogs,

              favoriteDogs: context.watch<app.AppState>().favoriteDogsNotifier.value,
              onToggleFavorite: context.watch<app.AppState>().onToggleFavorite,
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