import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/subscription/iap_service.dart';

class UpgradePage extends StatefulWidget {
  const UpgradePage({super.key});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  String selectedPlan = "premium";
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

  @override
  Widget build(BuildContext context) {
    final premium = IapService.instance.premiumProduct;
    final gold = IapService.instance.goldProduct;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Go Premium"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium,
                    color: Colors.amber, size: 50),
                const SizedBox(height: 10),
                Text(
                  "Unlock Premium Features",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Find better matches, get exclusive offers & stand out",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPlanCard(
                  title: "Premium",
                  price: premium?.price ?? "Loading...",
                  features: const [
                    "Unlimited playdate requests",
                    "Access premium offers",
                    "Priority in discovery",
                  ],
                  isSelected: selectedPlan == "premium",
                  onTap: () => setState(() => selectedPlan = "premium"),
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  title: "Gold",
                  price: gold?.price ?? "Loading...",
                  features: const [
                    "Everything in Premium",
                    "Top profile boost",
                    "Exclusive VIP offers",
                  ],
                  isSelected: selectedPlan == "gold",
                  isGold: true,
                  onTap: () => setState(() => selectedPlan = "gold"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isBusy ? null : () async {
                      final product = selectedPlan == "premium"
                          ? IapService.instance.premiumProduct
                          : IapService.instance.goldProduct;

                      if (product == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Store product not loaded yet."),
                          ),
                        );
                        return;
                      }

                      setState(() => isBusy = true);

                      try {
                        await IapService.instance.buySubscription(product);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Purchase failed: $e")),
                        );
                      } finally {
                        if (mounted) setState(() => isBusy = false);
                      }
                    },
                    child: Text(
                      isBusy
                          ? "Processing..."
                          : "Upgrade to ${selectedPlan.toUpperCase()}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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
                      const SnackBar(
                        content: Text("Restore request sent."),
                      ),
                    );
                  },
                  child: const Text("Restore Purchases"),
                ),
                Text(
                  "Cancel anytime • Secure payment",
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isSelected,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white12,
            width: 1.5,
          ),
          gradient: isGold
              ? const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                )
              : null,
          color: isGold ? null : const Color(0xFF1A1A1A),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isGold ? Colors.black : Colors.white,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: isGold ? Colors.black : Colors.amber),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isGold ? Colors.black : Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check,
                        size: 14,
                        color: isGold ? Colors.black : Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isGold ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}