import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    hide AppState;
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart' as app;

class BannerAdWidget extends StatefulWidget {
  final bool useTestAds;

  const BannerAdWidget({
    super.key,
    this.useTestAds = true,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  String get _adUnitId {
    if (widget.useTestAds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }

    return Platform.isIOS
        ? 'YOUR_REAL_IOS_BANNER_ID'
        : 'YOUR_REAL_ANDROID_BANNER_ID';
  }

  @override
  void initState() {
    super.initState();

    final appState = context.read<app.AppState>();

    // 🚫 Premium / Gold users should never load ads
    if (!appState.shouldShowAds) {
      debugPrint('🚫 Banner ads disabled for premium user');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner ad loaded');

          if (!mounted) return;

          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner failed: $error');

          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<app.AppState>();

    // 🚫 Extra safety for premium users
    if (!appState.shouldShowAds) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}