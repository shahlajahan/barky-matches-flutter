import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:barky_matches_fixed/services/mobile_advertising_service.dart';

class BannerAdWidget extends StatefulWidget {
  final bool useTestAds;

  const BannerAdWidget({super.key, this.useTestAds = kDebugMode});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  static const int _maxLoadAttempts = 2;

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _loadAttempts = 0;
  Timer? _retryTimer;

  String get _adUnitId {
    if (kDebugMode && widget.useTestAds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }

    return Platform.isIOS
        ? 'ca-app-pub-8741190851877191/6193026376'
        : 'ca-app-pub-8741190851877191/2113195813';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) return;

    final appState = context.read<app.AppState>();
    final ads = context.read<MobileAdvertisingService>();

    if (!appState.shouldShowAds) {
      _disposeAd(reason: 'paid_access');
      return;
    }

    if (ads.canRequestAds) {
      _loadIfEligible();
    }
  }

  void _loadIfEligible() {
    if (kIsWeb || _isLoaded || _isLoading || _bannerAd != null) return;
    if (_loadAttempts >= _maxLoadAttempts) return;

    final appState = context.read<app.AppState>();
    final ads = context.read<MobileAdvertisingService>();
    if (!appState.shouldShowAds || !ads.canRequestAds) return;

    _isLoading = true;
    _loadAttempts += 1;
    debugPrint('[MobileAds] banner request attempted attempt=$_loadAttempts');

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[MobileAds] banner loaded');

          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[MobileAds] banner failed code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );

          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isLoaded = false;
            _bannerAd = null;
          });
          _scheduleRetry();
        },
        onAdImpression: (ad) {
          debugPrint('[MobileAds] banner impression recorded');
        },
        onAdClicked: (ad) {
          debugPrint('[MobileAds] banner click recorded');
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          debugPrint(
            '[MobileAds] banner paid event currency=$currencyCode '
            'precision=${precision.name}',
          );
        },
      ),
    );

    _bannerAd!.load();
  }

  void _scheduleRetry() {
    if (_loadAttempts >= _maxLoadAttempts) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 2 * _loadAttempts), () {
      if (!mounted) return;
      _loadIfEligible();
    });
  }

  void _disposeAd({required String reason}) {
    _retryTimer?.cancel();
    _retryTimer = null;
    final ad = _bannerAd;
    _bannerAd = null;
    _isLoaded = false;
    _isLoading = false;
    if (ad != null) {
      debugPrint('[MobileAds] banner disposed reason=$reason');
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _disposeAd(reason: 'widget_dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final appState = context.watch<app.AppState>();
    final ads = context.watch<MobileAdvertisingService>();

    if (!appState.shouldShowAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _disposeAd(reason: 'paid_access_update');
      });
      return const SizedBox.shrink();
    }

    if (ads.canRequestAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadIfEligible();
      });
    } else {
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
