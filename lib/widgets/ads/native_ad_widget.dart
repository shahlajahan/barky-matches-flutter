import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    hide AppState;
import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:provider/provider.dart';

class NativeAdWidget extends StatefulWidget {
  final bool useTestAds;

  const NativeAdWidget({
    super.key,
    this.useTestAds = true,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  String get _adUnitId {
    if (widget.useTestAds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/3986624511'
          : 'ca-app-pub-3940256099942544/2247696110';
    }

    return Platform.isIOS
        ? 'YOUR_REAL_IOS_NATIVE_ID'
        : 'YOUR_REAL_ANDROID_NATIVE_ID';
  }

  @override
  void initState() {
    super.initState();

    final appState = context.read<app.AppState>();

    // 🚫 Premium / Gold users should never load ads
    if (!appState.shouldShowAds) {
      debugPrint('🚫 Native ads disabled for premium user');
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native ad loaded');

          if (!mounted) return;

          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed: $error');

          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<app.AppState>();

    // 🚫 Extra safety for premium users
    if (!appState.shouldShowAds) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      height: 120,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}