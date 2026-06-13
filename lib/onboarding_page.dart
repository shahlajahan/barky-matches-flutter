import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
  _OnboardingItem(
    image: "assets/onboarding/slide1.png",
    title: "Welcome to PetSupo",
    subtitle: "Everything your pet needs,\nall in one place.",
  ),
  _OnboardingItem(
    image: "assets/onboarding/slide2.png",
    title: "Veterinary Care",
    subtitle: "Trusted care,\nwhen your pet needs it most.",
  ),
  _OnboardingItem(
    image: "assets/onboarding/slide3.png",
    title: "Adoption & Community",
    subtitle: "Because every pet\ndeserves a loving home.",
  ),
  _OnboardingItem(
  image: "assets/onboarding/slide4.png",
  title: "Your Journey Begins",
  subtitle:
      "Making life better\nfor pets and their people.",
),
];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _next() {
    if (_currentPage == _items.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Image.asset(
                "assets/image/logo.png",
                height: 56,
              ),

              const SizedBox(height: 14),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];

                    return Column(
                      children: [
                        Expanded(
                          child: Transform.scale(
                            scale: 1.03,
                            child: Image.asset(
                              item.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2F2418),
                            height: 1.1,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: _currentPage == index ? 10 : 9,
                    height: _currentPage == index ? 10 : 9,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xFF9E1B4F)
                          : Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E1B4F),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    isLastPage ? "Get Started" : "Next",
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _finish,
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    color: Color(0xFFE91E63),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String image;
  final String title;
  final String subtitle;

  const _OnboardingItem({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}