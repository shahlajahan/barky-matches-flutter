import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:barky_matches_fixed/app_state.dart' as app;
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/services/mobile_advertising_service.dart';

class NativeAdWidget extends StatefulWidget {
  final bool useTestAds;

  const NativeAdWidget({super.key, this.useTestAds = kDebugMode});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  static const int _maxLoadAttempts = 2;

  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _loadAttempts = 0;
  Timer? _retryTimer;

  String get _adUnitId {
    if (kDebugMode && widget.useTestAds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/3986624511'
          : 'ca-app-pub-3940256099942544/2247696110';
    }

    return Platform.isIOS
        ? 'ca-app-pub-8741190851877191/7147015390'
        : 'ca-app-pub-8741190851877191/9560558142';
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
    if (kIsWeb || _isLoaded || _isLoading || _nativeAd != null) return;
    if (_loadAttempts >= _maxLoadAttempts) return;

    final appState = context.read<app.AppState>();
    final ads = context.read<MobileAdvertisingService>();
    if (!appState.shouldShowAds || !ads.canRequestAds) return;

    _isLoading = true;
    _loadAttempts += 1;
    debugPrint('[MobileAds] native request attempted attempt=$_loadAttempts');

    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('[MobileAds] native loaded');

          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[MobileAds] native failed code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );

          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isLoaded = false;
            _nativeAd = null;
          });
          _scheduleRetry();
        },
        onAdImpression: (ad) {
          debugPrint('[MobileAds] native impression recorded');
        },
        onAdClicked: (ad) {
          debugPrint('[MobileAds] native click recorded');
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          debugPrint(
            '[MobileAds] native paid event currency=$currencyCode '
            'precision=${precision.name}',
          );
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );

    _nativeAd!.load();
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
    final ad = _nativeAd;
    _nativeAd = null;
    _isLoaded = false;
    _isLoading = false;
    if (ad != null) {
      debugPrint('[MobileAds] native disposed reason=$reason');
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

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
