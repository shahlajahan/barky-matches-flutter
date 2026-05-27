import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class TestBannerAd extends StatefulWidget {
  const TestBannerAd({super.key});

  @override
  State<TestBannerAd> createState() => _TestBannerAdState();
}

class _TestBannerAdState extends State<TestBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner loaded');
          setState(() {});
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
    if (_bannerAd == null) {
      return const SizedBox();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
