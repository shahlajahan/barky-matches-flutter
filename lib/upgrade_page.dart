import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  String selectedPlan = "gold";
  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    _ensureStoreLoaded();
  }

  Future<void> _ensureStoreLoaded() async {
    if (IapService.instance.products.isEmpty) {
      await IapService.instance.init();
      if (mounted) setState(() {});
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = IapService.instance.premiumProduct;
    final gold = IapService.instance.goldProduct;

    final selectedProduct = selectedPlan == "premium" ? premium : gold;

    return Scaffold(
      backgroundColor: const Color(0xFF120914),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(),
        title: Text(
          l10n.upgradePageTitle,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                children: [
                  const Icon(Icons.pets, color: Color(0xFFFFC107), size: 54),
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

                  const SizedBox(height: 22),

                  _buildPlanCard(
                    title: l10n.premiumLabel,
                    subtitle: l10n.premiumPlanSubtitle,
                    price: premium?.price ?? l10n.loadingLabel,
                    isSelected: selectedPlan == "premium",
                    isGold: false,
                    features: [
                      l10n.premiumPlanFeatureUnlimitedChat,
                      l10n.premiumPlanFeatureAdvancedMatchingFilters,
                      l10n.premiumPlanFeatureExclusivePetOffers,
                      l10n.premiumPlanFeatureBetterProfileExperience,
                    ],
                    onTap: () => setState(() => selectedPlan = "premium"),
                  ),

                  const SizedBox(height: 14),

                  _buildPlanCard(
                    title: l10n.goldLabel,
                    subtitle: l10n.goldPlanSubtitle,
                    price: gold?.price ?? l10n.loadingLabel,
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
                      onPressed: isBusy
                          ? null
                          : () async {
                              if (selectedProduct == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.storeNotReadyTryAgain),
                                  ),
                                );
                                return;
                              }

                              setState(() => isBusy = true);

                              try {
                                debugPrint(
                                  "🛒 PAYWALL BUY TAP → $selectedPlan",
                                );
                                await IapService.instance.buySubscription(
                                  selectedProduct,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.errorOccurred(e.toString()),
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => isBusy = false);
                              }
                            },
                      child: Text(
                        isBusy
                            ? l10n.processingLabel
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

                  TextButton(
                    onPressed: () async {
                      await IapService.instance.restorePurchases();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.restoreRequestSent)),
                      );
                    },
                    child: Text(l10n.restorePurchases),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    l10n.upgradePaymentTerms,
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
                        onTap: () =>
                            _openUrl("https://petsupo.com/gizlilik-politikasi"),
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
                        onTap: () =>
                            _openUrl("https://petsupo.com/kullanim-kosullari"),
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
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required bool isGold,
    required List<String> features,
    required VoidCallback onTap,
    String? badge,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.autoRenewableMonthlySubscription,
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
              l10n.securePaymentNotice,
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
