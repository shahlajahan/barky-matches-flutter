import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dog.dart';
import 'auth_page.dart';
import 'offers_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
// برای دسترسی به MyApp
import 'package:barky_matches_fixed/ui/welcome/preview_dogs_section.dart';
import 'theme/app_theme.dart';
import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:barky_matches_fixed/core/debug/auth_boot_trace.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/home_gate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'package:barky_matches_fixed/services/social_auth_service.dart';
import 'package:barky_matches_fixed/core/debug/authentication_diagnostics.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';
import 'onboarding_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class WebAuthStartupGate extends StatefulWidget {
  const WebAuthStartupGate({required this.child, super.key});

  final Widget child;

  @override
  State<WebAuthStartupGate> createState() => _WebAuthStartupGateState();
}

class _WebAuthStartupGateState extends State<WebAuthStartupGate> {
  bool _ready = !kIsWeb;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) unawaited(_resumePendingRedirect());
  }

  Future<void> _resumePendingRedirect() async {
    final service = SocialAuthService();
    try {
      await ensureFirebase();
      final hasPendingRedirect = await service.hasPendingWebRedirect();
      if (!hasPendingRedirect) {
        if (mounted) setState(() => _ready = true);
        return;
      }

      final loginMode = await service.pendingWebRedirectLoginMode() ?? false;
      final result = await service.consumeWebRedirectResult();
      if (result != null && mounted) {
        await completeSocialAuthentication(
          context: context,
          initialResult: result,
          service: service,
          l10n: AppLocalizations.of(context)!,
          isLogin: loginMode,
        );
      }
      if (mounted) setState(() => _ready = true);
    } on SocialAuthCancelled {
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.authenticationCancelled,
            ),
          ),
        );
      });
    } on FirebaseAuthException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Web startup redirect authentication failed: '
          'code=${error.code} message=${error.message}\n$stackTrace',
        );
      }
      AuthenticationDiagnostics.captureFailure(
        operation: 'web_startup_redirect_auth',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.unableToSignIn)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
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

    _initPage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });

    // 🔥 PULSE INIT
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.18, end: 1.26).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureOffer();
    });
  }

  /*
Future<void> debugFirestoreRestOffers() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final projectId = Firebase.app().options.projectId;

    final idToken = await user?.getIdToken(true);

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/offers',
    );

    final response = await http.get(
      uri,
      headers: {
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      },
    );

    debugPrint('🌐 FIRESTORE REST STATUS: ${response.statusCode}');
    debugPrint('🌐 FIRESTORE REST BODY: ${response.body}');
  } catch (e, st) {
    debugPrint('🌐 FIRESTORE REST ERROR: $e');
    debugPrint('$st');
  }
}
*/
  Future<void> _initPage() async {
    final appState = context.read<app.AppState>();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    if (appState.consumeSessionRecoveryNotice()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.sessionExpiredPleaseSignInAgain),
          ),
        );
      });
    }

    unawaited(() async {
      debugPrint('OFFERS EARLY SKIPPED');

      if (OffersManager.offerCount == 0) {
        debugPrint('🌐 OFFERS EMPTY → waiting for async Firestore load');

        await Future.delayed(const Duration(milliseconds: 4500));
      }

      if (!mounted) return;

      debugPrint('🌐 OFFERS REBUILD → count=${OffersManager.offerCount}');

      setState(() {});
    }());
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

  Future<void> testHttp() async {
    try {
      final response = await http.get(Uri.parse("https://google.com"));
      debugPrint("🌐 HTTP STATUS: ${response.statusCode}");
    } catch (e) {
      debugPrint("❌ HTTP ERROR: $e");
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;

    if (hasSeen || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingPage(),
        ),
      );
    });
  }

  void _openSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthPage(
          isLogin: false,
          onAuthSuccess: () {
            final appState = context.read<app.AppState>();
            appState.setCurrentTab(NavTab.home);

            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          favoriteDogs: context.read<app.AppState>().favoriteDogsNotifier.value,
          onToggleFavorite: context.read<app.AppState>().onToggleFavorite,
        ),
      ),
    );
  }

  Future<void> _openAdoptionAsGuest() async {
    debugPrint("🟡 Welcome → set tab = NavTab.adoption");

    setState(() {
      _isLoading = true;
    });

    final appState = context.read<app.AppState>();
    final navigator = Navigator.of(context);

    await appState.enterGuestMode();
    appState.setCurrentTab(NavTab.adoption);

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeGate()),
      (route) => false,
    );
  }

  Future<void> _exploreAsGuest() async {
    try {
      final appState = context.read<app.AppState>();
      final navigator = Navigator.of(context);

      await appState.enterGuestMode();

      debugPrint('🚫 Guest mode → no notification permission');

      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Guest login error: $e');
    }
  }

  Widget _buildActivationSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.howWouldYouLikeToStart,
            style: AppTheme.h2().copyWith(color: const Color(0xFF9E1B4F)),
          ),
          const SizedBox(height: 10),
          _ActivationCard(
            icon: LucideIcons.dog,
            title: "I have a pet",
            subtitle:
                "Track health, discover services, and build your pet profile.",
            cta: "Create My Account",
            onTap: _openSignUp,
          ),
          const SizedBox(height: 8),
          _ActivationCard(
            icon: LucideIcons.heart,
            title: "I'm looking to adopt",
            subtitle: "Browse adoptable pets and connect with shelters.",
            cta: "Explore Adoption",
            onTap: _openAdoptionAsGuest,
          ),
          const SizedBox(height: 8),
          _ActivationCard(
            icon: LucideIcons.compass,
            title: "Explore as guest",
            subtitle: "Discover PetSupo before creating an account.",
            cta: "Continue",
            onTap: _exploreAsGuest,
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), // 🔥 حل مشکل
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10),
        ],
      ),
      child: Image.asset("assets/image/logo.png", height: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Presentation marker: proves in the durable trace whether the
    // signed-out entry point was actually rendered, and under which
    // restoration phase.
    AuthBootTrace.record(
      'welcome_page_build',
      data: <String, Object?>{
        'phase': context.read<app.AppState>().authRestorationPhase.name,
      },
    );

    final appState = context.read<app.AppState>();

    final favoriteDogs = appState.favoriteDogsNotifier.value;
    final onToggleFavorite = appState.onToggleFavorite;

    final previewDogs = appState.allDogs.take(3).toList();

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
                            AppLocalizations.of(
                              context,
                            )!.welcomeToPetSopuWithWave,
                            style: AppTheme.h1().copyWith(
                              color: const Color(0xFF9E1B4F),
                            ),
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
                                child: SizedBox(
                                  height: 168,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.transparent,
                                      boxShadow: [
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
                                        fit: StackFit.expand,
                                        children: [
                                          Positioned.fill(
                                            child: ValueListenableBuilder<int>(
                                              valueListenable:
                                                  OffersManager.offersVersion,
                                              builder: (context, _, __) {
                                                return OffersManager.buildOffersSection(
                                                  context,
                                                  null,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // 🐾 LOGO
                              Expanded(
                                child: SizedBox(
                                  height: 168,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF9E1B4F,
                                      ), // رنگ برند
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _pulseAnimation == null
                                              ? _buildLogo()
                                              : AnimatedBuilder(
                                                  animation: _pulseAnimation!,
                                                  builder: (context, child) {
                                                    return Transform.scale(
                                                      scale: _pulseAnimation!
                                                          .value,
                                                      child: child,
                                                    );
                                                  },
                                                  child: _buildLogo(),
                                                ),
                                          const SizedBox(height: 10),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.moreThanAnApp,
                                            textAlign: TextAlign.center,
                                            style: AppTheme.caption(
                                              color: Colors.white,
                                              weight: FontWeight.w600,
                                            ).copyWith(height: 1.25),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        PreviewDogsSection(previewDogs: previewDogs),

                        const SizedBox(height: 8),

                        // 🔐 AUTH BUTTONS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SignUpButton(
                                  onAuthSuccess: () {
                                    final appState = context
                                        .read<app.AppState>();
                                    appState.setCurrentTab(NavTab.home);

                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  },
                                  favoriteDogs: favoriteDogs,
                                  onToggleFavorite: onToggleFavorite,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SignInButton(
                                  onAuthSuccess: () {
                                    final appState = context
                                        .read<app.AppState>();
                                    appState.setCurrentTab(NavTab.home);

                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                  },
                                  favoriteDogs: favoriteDogs,
                                  onToggleFavorite: onToggleFavorite,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        _buildActivationSection(context),

                        const SizedBox(height: 16),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UpgradePage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.viewPremiumPlans,
                                style: AppTheme.button().copyWith(fontSize: 16),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🌍 LANGUAGE
                        Center(
                          child: Builder(
                            builder: (context) {
                              // Reads the canonical locale from AppState
                              // instead of SharedPreferences, so the selector
                              // always matches the active language and
                              // updates immediately after a change.
                              final selectedLanguage = context
                                  .watch<app.AppState>()
                                  .locale
                                  .languageCode;

                              return DropdownButton<String>(
                                value: selectedLanguage,
                                items: ['en', 'fa', 'tr', 'ru'].map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value == 'en'
                                          ? 'English'
                                          : value == 'fa'
                                          ? 'فارسی'
                                          : value == 'tr'
                                          ? 'Türkçe'
                                          : 'Русский',
                                      style: AppTheme.body(),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  if (value == null) return;

                                  // Canonical path: AppState updates state,
                                  // notifies, and persists.
                                  await context.read<app.AppState>().setLocale(
                                    value,
                                  );
                                },
                                dropdownColor: Colors.white,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

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
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  const _ActivationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow(opacity: 0.08),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.card.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(icon, color: AppTheme.card, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.h3(color: AppTheme.textDark)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTheme.body(color: AppTheme.muted, size: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cta,
                      style: AppTheme.button(
                        color: AppTheme.card,
                      ).copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                color: AppTheme.card.withOpacity(0.55),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onAuthSuccess;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const _SignInButton({
    required this.onAuthSuccess,
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
            builder: (_) => AuthPage(
              isLogin: true, // ✅ مهم
              onAuthSuccess: onAuthSuccess,
              favoriteDogs: favoriteDogs, // ✅ بدون context.select
              onToggleFavorite: onToggleFavorite,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),

        side: BorderSide(
          // 🔥 اینو اضافه کن
          color: Colors.pink.withOpacity(0.3),
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        localizations.signInButton,
        style: AppTheme.button().copyWith(fontSize: 16),
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  final VoidCallback onAuthSuccess;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const _SignUpButton({
    required this.onAuthSuccess,
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
            builder: (_) => AuthPage(
              isLogin: false,
              onAuthSuccess: onAuthSuccess,
              favoriteDogs: favoriteDogs, // ✅ بدون context.select
              onToggleFavorite: onToggleFavorite,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        localizations.signUpButton,
        style: AppTheme.button().copyWith(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
