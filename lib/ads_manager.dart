import 'package:flutter/material.dart'; // ✅ خیلی مهم
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsManager {
  static late BannerAd _bannerAd;
  static bool _isLoaded = false;

  static void initializeAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Ad failed to load: ${error.message} (code: ${error.code})',
          );
          ad.dispose();
        },
      ),
    )..load();
  }

  static void disposeAd() {
    if (_isLoaded) {
      _bannerAd.dispose();
      _isLoaded = false;
    }
  }

  static Widget buildWelcomeAd() {
    if (!_isLoaded) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: _bannerAd.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd),
      ),
    );
  }

  static Widget buildInAppAd(bool isPremium) {
    if (isPremium || !_isLoaded) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: _bannerAd.size.height.toDouble(),
        width: _bannerAd.size.width.toDouble(),
        child: AdWidget(ad: _bannerAd),
      ),
    );
  }
}
