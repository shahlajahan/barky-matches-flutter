import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';

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
    final premium = IapService.instance.premiumProduct;
    final gold = IapService.instance.goldProduct;

    final selectedProduct = selectedPlan == "premium" ? premium : gold;

    return Scaffold(
      backgroundColor: const Color(0xFF120914),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Upgrade",
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
                    "Find better matches faster 🐾",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Unlock premium features, better visibility, exclusive offers and business tools.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 22),

                  _buildPlanCard(
                    title: "Premium",
                    subtitle: "For dog owners who want more matches",
                    price: premium?.price ?? "Loading...",
                    isSelected: selectedPlan == "premium",
                    isGold: false,
                    features: const [
                      "Unlimited chat",
                      "Advanced matching filters",
                      "Exclusive pet offers",
                      "Better profile experience",
                    ],
                    onTap: () => setState(() => selectedPlan = "premium"),
                  ),

                  const SizedBox(height: 14),

                  _buildPlanCard(
                    title: "Gold",
                    subtitle: "Best for business access and maximum visibility",
                    price: gold?.price ?? "Loading...",
                    isSelected: selectedPlan == "gold",
                    isGold: true,
                    badge: "MOST POPULAR",
                    features: const [
                      "Everything in Premium",
                      "Business registration access",
                      "Boosted visibility",
                      "Business dashboard access",
                      "Premium chat and offers",
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
                                  const SnackBar(
                                    content: Text("Store not ready. Try again."),
                                  ),
                                );
                                return;
                              }

                              setState(() => isBusy = true);

                              try {
                                debugPrint("🛒 PAYWALL BUY TAP → $selectedPlan");
                                await IapService.instance.buySubscription(
                                  selectedProduct,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Purchase failed: $e"),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => isBusy = false);
                              }
                            },
                      child: Text(
                        isBusy
                            ? "Processing..."
                            : "Continue with ${selectedPlan.toUpperCase()}",
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
                        const SnackBar(content: Text("Restore request sent.")),
                      );
                    },
                    child: const Text("Restore Purchases"),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Payment will be charged to your Apple ID account at confirmation. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. You can manage or cancel subscriptions in your App Store account settings.",
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
                        onTap: () => _openUrl("https://petsupo.com/gizlilik-politikasi"),
                        child: const Text(
                          "Privacy Policy",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () => _openUrl("https://petsupo.com/kullanim-kosullari"),
                        child: const Text(
                          "Terms of Use",
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: subColor,
              ),
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
              "per month",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: subColor,
              ),
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
              "Secure payment • Cancel anytime • Plans are managed by the App Store",
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