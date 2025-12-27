import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'welcome_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('SplashScreen - Initializing...');
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // تنظیم مدت زمان انیمیشن
    );
    _controller.addStatusListener((status) {
      if (kDebugMode) {
        print('SplashScreen - Animation status: $status');
      }
      if (status == AnimationStatus.completed) {
        if (kDebugMode) {
          print('SplashScreen - Animation completed, navigating to WelcomePage');
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    });

    // انیمیشن برای متن
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // هدایت خودکار بعد از 10 ثانیه در صورت شکست انیمیشن
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_controller.isCompleted) {
        if (kDebugMode) {
          print('SplashScreen - Animation timeout, forcing navigation to WelcomePage');
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    });

    // شروع انیمیشن
    if (kDebugMode) {
      print('SplashScreen - Starting animation');
    }
    _controller.forward();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('SplashScreen - Disposing controller');
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('SplashScreen - Building UI');
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset(
                'assets/animations/dog_animation.json',
                controller: _controller,
                onLoaded: (composition) {
                  if (kDebugMode) {
                    print('SplashScreen - Lottie animation loaded, duration: ${composition.duration}');
                  }
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    print('SplashScreen - Error loading Lottie animation: $error');
                  }
                  return const Icon(Icons.error, size: 100, color: Colors.white);
                },
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _textAnimation,
              child: Text(
                'Find the perfect playmate for your pup!',
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFC107),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}