import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_browser.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_service.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

const double webUpgradeContentMaxWidth = 1100;

bool mobileIapPurchaseControlsEnabled() => IapService.mobileIapEnabled;

double upgradeContentWidth({
  required double viewportWidth,
  required bool isWeb,
}) {
  if (isWeb && viewportWidth > webUpgradeContentMaxWidth) {
    return webUpgradeContentMaxWidth;
  }
  return viewportWidth;
}

class UpgradePage extends StatefulWidget {
  final VoidCallback? onClose;

  const UpgradePage({super.key, this.onClose});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  String selectedPlan = "gold";
  bool isBusy = false;
  final WebSubscriptionService _webSubscriptionService =
      WebSubscriptionService();
  final ScrollController _webScrollController = ScrollController();
  Map<String, WebSubscriptionPlanPresentation> _webPlans = const {};
  bool _webCatalogLoading = false;
  bool _webCheckoutAvailable = false;
  WebSubscriptionCatalogFailure? _webCatalogFailure;

  @override
  void initState() {
    super.initState();

    debugPrint(
      "🔥 UpgradePage created hash=${identityHashCode(this)} "
      "onClose=${widget.onClose != null}",
    );

    if (kIsWeb) {
      _loadWebCatalog();
    } else {
      IapService.instance.setSubscriptionErrorCallback((reason) async {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        if (l10n == null) return;
        final message = reason == IapService.ownershipConflictReason
            ? l10n.mobileSubscriptionOwnershipConflict
            : l10n.mobileSubscriptionVerificationFailed;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
      _ensureStoreLoaded();
    }
  }

  Future<void> _ensureStoreLoaded() async {
    if (kIsWeb || !IapService.mobileIapEnabled) return;
    if (IapService.instance.products.isNotEmpty) return;
    try {
      await IapService.instance.init();
    } catch (error, stack) {
      debugPrint('🛒 STORE INIT ERROR: $error\n$stack');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadWebCatalog() async {
    if (!kIsWeb) return;
    setState(() {
      _webCatalogLoading = true;
      _webCatalogFailure = null;
    });
    try {
      final plans = await _webSubscriptionService.loadCatalog();
      if (!mounted) return;
      setState(() {
        _webPlans = plans;
        _webCheckoutAvailable =
            plans.containsKey('premium') && plans.containsKey('gold');
      });
    } on WebSubscriptionCatalogException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Web subscription catalog unavailable: '
          'failure=${error.failure}, code=${error.code}, '
          'message=${error.message}',
        );
      }
      if (!mounted) return;
      setState(() {
        _webPlans = const {};
        _webCheckoutAvailable = false;
        _webCatalogFailure = error.failure;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unexpected Web subscription catalog failure: $error');
      }
      if (!mounted) return;
      setState(() {
        _webPlans = const {};
        _webCheckoutAvailable = false;
        _webCatalogFailure = WebSubscriptionCatalogFailure.malformedResponse;
      });
    } finally {
      if (mounted) setState(() => _webCatalogLoading = false);
    }
  }

  Future<void> _startWebCheckout() async {
    if (!kIsWeb || isBusy || !_webCheckoutAvailable) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => isBusy = true);
    try {
      final session = await _webSubscriptionService.createCheckout(
        selectedPlan,
      );
      await submitWebSubscriptionCheckout(session.html);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.webSubscriptionCheckoutFailed)),
      );
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _webScrollController.dispose();
    super.dispose();
  }

  String _webCatalogErrorMessage(AppLocalizations l10n) {
    return switch (_webCatalogFailure) {
      WebSubscriptionCatalogFailure.unauthenticated =>
        l10n.webSubscriptionCatalogUnauthenticated,
      WebSubscriptionCatalogFailure.functionNotFound =>
        l10n.webSubscriptionCatalogFunctionNotFound,
      WebSubscriptionCatalogFailure.configuration =>
        l10n.webSubscriptionCatalogConfigurationMissing,
      WebSubscriptionCatalogFailure.network =>
        l10n.webSubscriptionCatalogNetworkFailed,
      WebSubscriptionCatalogFailure.malformedResponse =>
        l10n.webSubscriptionCatalogMalformed,
      null => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔥 UpgradePage BUILD onClose=${widget.onClose != null}");
    final l10n = AppLocalizations.of(context)!;
    final premium = kIsWeb ? null : IapService.instance.premiumProduct;
    final gold = kIsWeb ? null : IapService.instance.goldProduct;
    final mobileIapEnabled = mobileIapPurchaseControlsEnabled();

    final selectedProduct = selectedPlan == "premium" ? premium : gold;
    final webUnavailable = l10n.webSubscriptionPaymentUnavailable;

    return Scaffold(
      backgroundColor: const Color(0xFF120914),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              debugPrint("🔥 CLOSE ICON TAPPED");

              if (widget.onClose != null) {
                debugPrint("🔥 CALLING onClose()");
                widget.onClose!();
                return;
              }

              debugPrint("🔥 FALLBACK maybePop()");
              Navigator.of(context).maybePop();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        title: Text(
          l10n.upgradePageTitle,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: upgradeContentWidth(
                  viewportWidth: constraints.maxWidth,
                  isWeb: kIsWeb,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: kIsWeb ? _webScrollController : null,
                        padding: EdgeInsets.fromLTRB(
                          18,
                          kIsWeb ? 18 : 10,
                          18,
                          72,
                        ),
                        children: [
                          const Icon(
                            Icons.pets,
                            color: Color(0xFFFFC107),
                            size: 54,
                          ),
                          const SizedBox(height: 12),

                          Text(
                            l10n.upgradeHeroTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            l10n.upgradeHeroSubtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),

                          if (kIsWeb && _webCatalogFailure != null) ...[
                            const SizedBox(height: 14),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud_off_rounded,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _webCatalogErrorMessage(l10n),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _webCatalogLoading
                                          ? null
                                          : _loadWebCatalog,
                                      child: Text(l10n.retryButton),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          _buildPlanCard(
                            title: l10n.premiumLabel,
                            subtitle: l10n.premiumPlanSubtitle,
                            price: kIsWeb
                                ? (_webPlans['premium']?.formattedPrice ??
                                      webUnavailable)
                                : mobileIapEnabled
                                ? premium?.price ?? l10n.loadingLabel
                                : l10n.storeNotReadyTryAgain,
                            isSelected: selectedPlan == "premium",
                            isGold: false,
                            features: [
                              l10n.premiumPlanFeatureUnlimitedChat,
                              l10n.premiumPlanFeatureAdvancedMatchingFilters,
                              l10n.premiumPlanFeatureExclusivePetOffers,
                              l10n.premiumPlanFeatureBetterProfileExperience,
                            ],
                            purchaseTerms: kIsWeb
                                ? l10n.webSubscriptionThirtyDayAccess
                                : l10n.autoRenewableMonthlySubscription,
                            onTap: () =>
                                setState(() => selectedPlan = "premium"),
                          ),

                          const SizedBox(height: 14),

                          _buildPlanCard(
                            title: l10n.goldLabel,
                            subtitle: l10n.goldPlanSubtitle,
                            price: kIsWeb
                                ? (_webPlans['gold']?.formattedPrice ??
                                      webUnavailable)
                                : mobileIapEnabled
                                ? gold?.price ?? l10n.loadingLabel
                                : l10n.storeNotReadyTryAgain,
                            isSelected: selectedPlan == "gold",
                            isGold: true,
                            badge: l10n.mostPopularLabel,
                            features: [
                              l10n.goldPlanFeatureEverythingInPremium,
                              l10n.goldPlanFeatureBusinessRegistrationAccess,
                              l10n.goldPlanFeatureBoostedVisibility,
                              l10n.goldPlanFeatureBusinessDashboardAccess,
                              l10n.goldPlanFeaturePremiumChatAndOffers,
                            ],
                            purchaseTerms: kIsWeb
                                ? l10n.webSubscriptionThirtyDayAccess
                                : l10n.autoRenewableMonthlySubscription,
                            onTap: () => setState(() => selectedPlan = "gold"),
                          ),

                          const SizedBox(height: 18),

                          _buildTrustBox(),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed:
                                  isBusy ||
                                      (!kIsWeb && !mobileIapEnabled) ||
                                      (kIsWeb &&
                                          (_webCatalogLoading ||
                                              !_webCheckoutAvailable))
                                  ? null
                                  : () async {
                                      if (kIsWeb) {
                                        await _startWebCheckout();
                                        return;
                                      }
                                      if (selectedProduct == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.storeNotReadyTryAgain,
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => isBusy = true);

                                      try {
                                        debugPrint(
                                          "🛒 PAYWALL BUY TAP → $selectedPlan",
                                        );
                                        await IapService.instance
                                            .buySubscription(selectedProduct);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.errorOccurred(e.toString()),
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => isBusy = false);
                                        }
                                      }
                                    },
                              child: Text(
                                isBusy
                                    ? l10n.processingLabel
                                    : kIsWeb
                                    ? (_webCatalogLoading
                                          ? l10n.processingLabel
                                          : _webCheckoutAvailable
                                          ? l10n.webSubscriptionContinueSecurePayment
                                          : l10n.webSubscriptionPaymentUnavailable)
                                    : l10n.continueWithPlan(
                                        selectedPlan == "premium"
                                            ? l10n.premiumLabel
                                            : l10n.goldLabel,
                                      ),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (!kIsWeb && mobileIapEnabled)
                            TextButton(
                              onPressed: () async {
                                await IapService.instance.restorePurchases();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.restoreRequestSent),
                                  ),
                                );
                              },
                              child: Text(l10n.restorePurchases),
                            ),

                          const SizedBox(height: 4),

                          Text(
                            kIsWeb
                                ? l10n.webSubscriptionPaymentTerms
                                : l10n.upgradePaymentTerms,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: Colors.white54,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _openUrl(
                                  "https://petsupo.com/gizlilik-politikasi",
                                ),
                                child: Text(
                                  l10n.privacyPolicyLabel,
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              GestureDetector(
                                onTap: () => _openUrl(
                                  "https://petsupo.com/kullanim-kosullari",
                                ),
                                child: Text(
                                  l10n.termsOfUseLabel,
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required bool isGold,
    required List<String> features,
    required String purchaseTerms,
    required VoidCallback onTap,
    String? badge,
  }) {
    final bgColor = isGold ? const Color(0xFFFFC107) : const Color(0xFF211426);
    final textColor = isGold ? Colors.black : Colors.white;
    final subColor = isGold ? Colors.black87 : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: isGold
                    ? Colors.amber.withOpacity(0.35)
                    : Colors.pink.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: isGold ? Colors.black : const Color(0xFFFFC107),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: subColor),
            ),

            const SizedBox(height: 12),

            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),

            Text(
              purchaseTerms,
              style: GoogleFonts.poppins(fontSize: 11, color: subColor),
            ),

            const SizedBox(height: 14),

            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: isGold ? Colors.black : const Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBox() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kIsWeb
                  ? l10n.webSubscriptionIsbankSecurePayment
                  : l10n.securePaymentNotice,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
