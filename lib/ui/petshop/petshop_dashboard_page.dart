import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../business/petshop/add_product_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/ui/petshop/widgets/product_card_dashboard.dart';

import 'package:barky_matches_fixed/models/order_return.dart';
import 'package:barky_matches_fixed/ui/returns/order_return_card.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/ui/business/petshop/edit_petshop_profile_page.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/widgets/business_quick_actions.dart';

class PetShopDashboardPage extends StatefulWidget {
  const PetShopDashboardPage({super.key});

  @override
  State<PetShopDashboardPage> createState() => _PetShopDashboardPageState();
}

class _PetShopDashboardPageState extends State<PetShopDashboardPage> {
  String? _businessId;

  Stream<QuerySnapshot>? _revenueStream;
  Stream<QuerySnapshot>? _ordersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _returnsStream;

  Stream<DocumentSnapshot>? _profileStream;

  final ProductService _productService = ProductService();
  void _logFirestoreIndexLink(dynamic error, String tag) {
    final errorStr = error.toString();

    debugPrint("❌ $tag ERROR: $errorStr");

    final match = RegExp(
      r'https://console\.firebase\.google\.com[^\s]+',
    ).firstMatch(errorStr);

    if (match != null) {
      final indexUrl = match.group(0);
      debugPrint("🚀 $tag INDEX LINK:");
      debugPrint(indexUrl);
    } else {
      debugPrint("⚠️ $tag → No index link found");
    }
  }

  void _setupStreams(String businessId) {
    debugPrint("SETUP CALLED");
    debugPrint("_businessId=$_businessId");
    debugPrint("businessId=$businessId");
    debugPrint("_returnsStream=$_returnsStream");
    //if (_businessId == businessId) return;

    _businessId = businessId;

    _profileStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .snapshots();

    _revenueStream = FirebaseFirestore.instance
        .collection("sellerOrders")
        .where("shopId", isEqualTo: businessId)
        .snapshots(includeMetadataChanges: false);

    _ordersStream = FirebaseFirestore.instance
        .collection("sellerOrders")
        .where("shopId", isEqualTo: businessId)
        .orderBy("createdAt", descending: true)
        .limit(5)
        .snapshots();

    _returnsStream = FirebaseFirestore.instance
        .collection('order_returns')
        .where('businessId', isEqualTo: businessId)
        .orderBy('requestedAt', descending: true)
        .limit(5)
        .snapshots();
    debugPrint("===== RETURNS QUERY =====");
    debugPrint("businessId = $businessId");
    debugPrint("stream = $_returnsStream");
    debugPrint(
      "📡 RETURNS QUERY businessId=$businessId "
      "collection=order_returns "
      "orderBy=requestedAt",
    );

    debugPrint("✅ PETSHOP STREAMS SETUP ONCE → businessId=$businessId");
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final businessId = context.select<AppState, String?>((s) => s.businessId);

    final businessSubPage = context.select<AppState, BusinessSubPage>(
      (s) => s.businessSubPage,
    );
    debugPrint("================================");
    debugPrint("businessSubPage = $businessSubPage");
    debugPrint("================================");
    // final businessId = appState.businessId;
    if (businessSubPage == BusinessSubPage.addProduct) {
      return AddProductPage(businessId: businessId!);
    }

    if (businessSubPage == BusinessSubPage.editProduct) {
      return AddProductPage(
        businessId: businessId!,
        existingProduct: context.read<AppState>().editingProduct,
      );
    }

    if (businessId == null) {
      return Center(child: Text(l10n.businessNotFound));
    }

    _setupStreams(businessId);

    if (businessSubPage == BusinessSubPage.petshopProducts) {
      return _buildDashboardShell(
        child: _buildBusinessSubPage(
          title: l10n.productsTitle,
          child: _buildProductsSection(context, businessId, showTitle: false),
        ),
      );
    }

    if (businessSubPage == BusinessSubPage.petshopOrders) {
      return _buildDashboardShell(
        child: _buildBusinessSubPage(
          title: l10n.ordersTitle,
          child: _buildOrdersSection(context, businessId, showHeader: false),
        ),
      );
    }

    if (businessSubPage == BusinessSubPage.petshopReturns) {
      return _buildDashboardShell(
        child: _buildBusinessSubPage(
          title: l10n.returnRequestsTitle,
          child: _buildReturnsSection(context, businessId, showHeader: false),
        ),
      );
    }

    if (businessSubPage == BusinessSubPage.petshopSettings) {
      return EditPetShopProfilePage(businessId: businessId);
    }

    debugPrint("🧠 DASHBOARD BUILD → businessId=$businessId");

    return _buildDashboardShell(child: _buildOverview(context, businessId));
  }

  Widget _buildDashboardShell({required Widget child}) {
    return Container(
      color: AppTheme.bg,
      child: SafeArea(child: child),
    );
  }

  Widget _buildOverview(BuildContext context, String businessId) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.shopProfileTitle, style: AppTheme.h2()),
        const SizedBox(height: 10),
        _buildProfileSection(context, businessId),
        const SizedBox(height: 20),

        Text("Revenue", style: AppTheme.h2()),
        const SizedBox(height: 10),
        _buildRevenueCard(context, businessId),
        const SizedBox(height: 20),

        Text("Daily Summary", style: AppTheme.h2()),
        const SizedBox(height: 10),
        _buildDailySummaryCards(context, businessId),
        const SizedBox(height: 20),

        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildBusinessSubPage({required String title, required Widget child}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: context.read<AppState>().closeBusinessSubPage,
              icon: const Icon(LucideIcons.arrowLeft),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(title, style: AppTheme.h2())),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildDailySummaryCards(BuildContext context, String businessId) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: _revenueStream,
      builder: (context, ordersSnapshot) {
        final orderDocs = ordersSnapshot.data?.docs ?? [];
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));

        final todaysOrders = orderDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data["createdAt"];
          if (createdAt is! Timestamp) return false;
          final createdDate = createdAt.toDate();
          return !createdDate.isBefore(todayStart) &&
              createdDate.isBefore(tomorrowStart);
        }).toList();

        double todaysRevenue = 0;
        for (final doc in todaysOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final financial = data["financial"] as Map<String, dynamic>?;
          final raw = financial?["sellerNetAmount"];
          todaysRevenue += raw is num
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? "") ?? 0;
        }

        final pendingOrders = orderDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _normalizeOrderStatus((data["status"] ?? "").toString()) ==
              "pending";
        }).length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _returnsStream,
          builder: (context, returnsSnapshot) {
            final pendingReturns =
                returnsSnapshot.data?.docs.where((doc) {
                  final status = (doc.data()["status"] ?? "")
                      .toString()
                      .toLowerCase();
                  return status == "pending";
                }).length ??
                0;

            return StreamBuilder<List<Product>>(
              stream: _productService.getProducts(businessId),
              builder: (context, productsSnapshot) {
                final products = productsSnapshot.data ?? [];
                final lowStock = products.where((p) => p.isLowStock).length;

                return Column(
                  children: [
                    Row(
                      children: [
                        _statBox(
                          l10n.ordersTitle,
                          todaysOrders.length.toString(),
                        ),
                        const SizedBox(width: 10),
                        _statBox(
                          "Today",
                          "₺${todaysRevenue.toStringAsFixed(0)}",
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statBox(
                          l10n.pendingStatusLabel,
                          pendingOrders.toString(),
                        ),
                        const SizedBox(width: 10),
                        _statBox(
                          l10n.lowStockLabel,
                          lowStock.toString(),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statBox(
                          l10n.returnRequestsTitle,
                          pendingReturns.toString(),
                        ),
                        const SizedBox(width: 10),
                        _statBox(
                          l10n.productsTitle,
                          products.length.toString(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BusinessQuickActionsSection(
      title: "Quick Actions",
      actions: [
        BusinessQuickActionItem(
          label: l10n.productsTitle,
          icon: LucideIcons.package,
          onTap: context.read<AppState>().openPetShopProducts,
        ),
        BusinessQuickActionItem(
          label: l10n.ordersTitle,
          icon: LucideIcons.receipt,
          onTap: context.read<AppState>().openPetShopOrders,
        ),
        BusinessQuickActionItem(
          label: l10n.returnRequestsTitle,
          icon: LucideIcons.rotateCcw,
          onTap: () {
            debugPrint("RETURN BUTTON CLICKED");
            context.read<AppState>().openPetShopReturns();
          },
        ),
        BusinessQuickActionItem(
          label: "Settings",
          icon: LucideIcons.settings,
          onTap: context.read<AppState>().openPetShopSettings,
        ),
      ],
    );
  }

  double calculateProductStrength(Product p) {
    double score = 0;

    if (p.name.trim().length >= 3) score += 20;
    if (p.description.trim().length >= 20) score += 20;
    if (p.media.isNotEmpty) score += 20;
    if (p.media.length >= 3) score += 10;
    if (p.price > 0) score += 15;
    if (p.stock > 0) score += 10;
    if (p.category != "general") score += 5;

    return score; // از 100
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "paid":
        return Colors.green;
      case "confirmed":
        return Colors.teal;
      case "preparing":
        return Colors.orange;
      case "shipped":
        return Colors.blue;
      case "delivered":
        return Colors.purple;
      case "failed":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _ensureSubMerchant(String businessId) async {
    final doc = await FirebaseFirestore.instance
        .collection("businesses")
        .doc(businessId)
        .get();

    final data = doc.data();

    if (data != null && data["subMerchantKey"] != null) {
      debugPrint("✅ subMerchant already exists");
      return;
    }

    debugPrint("🚀 creating subMerchant...");

    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');

    final res = await functions.httpsCallable('createSubMerchant').call({
      "businessId": businessId,
    });

    debugPrint("🔥 subMerchant created: ${res.data}");
  }

  Widget _buildProfileSection(BuildContext context, String businessId) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyBox(l10n.errorOccurred(snapshot.error.toString()));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
        final contact = (data['contact'] as Map<String, dynamic>?) ?? {};
        final sectorData = (data['sectorData'] as Map<String, dynamic>?) ?? {};
        final petshopData =
            (sectorData['petshop'] as Map<String, dynamic>?) ?? {};
        final petshopProfile =
            (petshopData['profile'] as Map<String, dynamic>?) ?? {};

        final shopName =
            (profile['displayName'] ??
                    profile['businessName'] ??
                    petshopData['shopName'] ??
                    'PetShop')
                .toString();

        final bio =
            (profile['bio'] ??
                    profile['description'] ??
                    petshopProfile['bio'] ??
                    '')
                .toString();

        final phone = (contact['phone'] ?? '').toString();
        final email = (contact['email'] ?? '').toString();
        final city = (contact['city'] ?? '').toString();
        final district = (contact['district'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shopName,
                      style: AppTheme.h3(weight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      context.read<AppState>().openPetShopSettings();
                    },
                    icon: const Icon(LucideIcons.edit2, size: 18),
                    label: Text(l10n.editProfile),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                bio.isNotEmpty ? bio : l10n.noDescriptionYet,
                style: AppTheme.body(
                  color: bio.isNotEmpty ? AppTheme.textDark : AppTheme.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (phone.isNotEmpty) _chip("${l10n.phoneLabel}: $phone"),
                  if (email.isNotEmpty) _chip("${l10n.emailLabel}: $email"),
                  if (district.isNotEmpty || city.isNotEmpty)
                    _chip(
                      "${l10n.locationLabel} ${[if (district.isNotEmpty) district, if (city.isNotEmpty) city].join(' / ')}",
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _normalizeOrderStatus(String s) {
    final lower = s.toLowerCase();

    if (lower.contains("pending")) return "pending";
    if (lower.contains("paid")) return "paid";
    if (lower.contains("confirmed")) return "confirmed";
    if (lower.contains("preparing")) return "preparing";
    if (lower.contains("shipped")) return "shipped";
    if (lower.contains("delivered")) return "delivered";
    if (lower.contains("fail")) return "failed";

    return lower;
  }

  Widget _orderStatusPill(String status) {
    final color = _orderStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTheme.caption(
          color: color,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  /*
Widget _strengthBar(double value) {
  Color color;

  if (value < 40) {
    color = Colors.red;
  } else if (value < 70) {
    color = Colors.orange;
  } else {
    color = Colors.green;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Product Strength"),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: value / 100,
        color: color,
        backgroundColor: Colors.grey.shade200,
      ),
      const SizedBox(height: 4),
      Text("${value.toInt()}%"),
    ],
  );
}
*/
  // =========================
  // 💰 REVENUE
  // =========================
  Widget _buildRevenueCard(BuildContext context, String businessId) {
    final l10n = AppLocalizations.of(context)!;
    if (kDebugMode) {
      debugPrint(
        '💰 REVENUE QUERY → authUid=${FirebaseAuth.instance.currentUser?.uid ?? "NULL"} '
        'businessId=$businessId path=sellerOrders where shopId==$businessId',
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _revenueStream,
      builder: (context, snapshot) {
        // ❌ ERROR
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
              '💰 REVENUE ERROR → authUid=${FirebaseAuth.instance.currentUser?.uid ?? "NULL"} '
              'businessId=$businessId path=sellerOrders error=${snapshot.error}',
            );
          }
          _logFirestoreIndexLink(snapshot.error, "REVENUE");
          return _emptyBox(l10n.errorOccurred(snapshot.error.toString()));
        }

        // ⏳ LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            debugPrint("⏳ REVENUE LOADING...");
          }
          return const Center(child: CircularProgressIndicator());
        }

        // ❌ EMPTY
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyBox(l10n.noRevenueYet);
        }

        // =====================
        // 🔢 CALCULATION
        // =====================
        double netRevenue = 0;
        double grossSales = 0;
        double commissionTotal = 0;
        double penaltyTotal = 0;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;

          final pricing = data["pricing"] as Map<String, dynamic>?;
          final financial = data["financial"] as Map<String, dynamic>?;

          double orderNet = 0;
          double orderGross = 0;
          double orderCommission = 0;
          double orderPenalty = 0;

          // ✅ NET
          if (financial != null && financial["sellerNetAmount"] != null) {
            final raw = financial["sellerNetAmount"];
            orderNet = raw is num
                ? raw.toDouble()
                : double.tryParse(raw.toString()) ?? 0;
          } else {
            continue; // ❌ skip old orders
          }

          // ✅ GROSS
          if (pricing != null && pricing["grandTotal"] != null) {
            final raw = pricing["grandTotal"];
            orderGross = raw is num
                ? raw.toDouble()
                : double.tryParse(raw.toString()) ?? 0;
          }

          // ✅ COMMISSION
          if (financial["commissionAmount"] != null) {
            final raw = financial["commissionAmount"];
            orderCommission = raw is num
                ? raw.toDouble()
                : double.tryParse(raw.toString()) ?? 0;
          }

          // 🔜 FUTURE
          orderPenalty = 0;

          // ➕ SUM
          netRevenue += orderNet;
          grossSales += orderGross;
          commissionTotal += orderCommission;
          penaltyTotal += orderPenalty;

          if (kDebugMode) {
            debugPrint("💸 ORDER ${doc.id} → net=$orderNet");
          }
        }

        if (kDebugMode) {
          debugPrint(
            "💰 FINAL → NET: $netRevenue | GROSS: $grossSales | COMMISSION: $commissionTotal",
          );
        }

        // =====================
        // 🎨 UI
        // =====================
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9E1B4F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🧾 TITLE
              Text(
                l10n.netRevenueLabel,
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              // 💰 MAIN VALUE
              Text(
                "₺${netRevenue.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              // 🧠 EXPLANATION
              Text(
                l10n.afterPlatformCommissionLabel,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),

              const SizedBox(height: 12),

              // 📊 BREAKDOWN
              _row(l10n.grossSalesLabel, grossSales),
              _row(l10n.platformFeeLabel, -commissionTotal),
              _row(l10n.adjustmentsLabel, -penaltyTotal),
            ],
          ),
        );
      },
    );
  }

  String _buildTrackingUrl(String carrier, String code) {
    switch (carrier.toLowerCase()) {
      case "aras":
        return "https://kargotakip.araskargo.com.tr/mainpage.aspx?code=$code";
      case "yurtici":
        return "https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=$code";
      case "mng":
        return "https://www.mngkargo.com.tr/gonderi-takip?code=$code";
      case "ptt":
        return "https://gonderitakip.ptt.gov.tr/Track/Verify?q=$code";
      case "hepsijet":
        return "https://www.hepsijet.com/gonderi-takibi/$code";
      case "sendeo":
        return "https://sendeo.com.tr/tracking/$code";
      default:
        return "";
    }
  }

  Widget _row(String title, double value) {
    final isNegative = value < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text(
            "${isNegative ? "-" : ""}₺${value.abs().toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // =========================
  // 📦 ORDERS
  // =========================
  Widget _buildOrdersSection(
    BuildContext context,
    String businessId, {
    bool showHeader = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(l10n.recentOrdersTitle, style: AppTheme.h2()),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        StreamBuilder<QuerySnapshot>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _logFirestoreIndexLink(snapshot.error, "ORDERS");
              return Text(l10n.errorOccurred(snapshot.error.toString()));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint("⏳ ORDERS LOADING...");
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              debugPrint("⚠️ ORDERS NO DATA");
              return Text(l10n.noDataLabel);
            }

            final docs = snapshot.data!.docs;
            debugPrint("📦 ORDERS COUNT: ${docs.length}");

            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    const Icon(LucideIcons.package, color: Colors.black38),
                    const SizedBox(width: 10),
                    Text(
                      l10n.noOrdersYet,
                      style: AppTheme.body(color: AppTheme.muted),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final pricing = data["pricing"] as Map<String, dynamic>?;
                final rawStatus = data["status"] ?? "pending";
                final status = _normalizeOrderStatus(rawStatus.toString());

                final totalRaw = pricing?["grandTotal"] ?? data["total"] ?? 0;
                final total = totalRaw is num
                    ? totalRaw.toDouble()
                    : double.tryParse(totalRaw.toString()) ?? 0;

                final items = data["items"] as List? ?? [];
                final createdAt = data["createdAt"];

                final shipping =
                    (data["shipping"] as Map<String, dynamic>?) ?? {};
                final carrier = (shipping["carrier"] ?? "").toString();
                final trackingNumber = (shipping["trackingNumber"] ?? "")
                    .toString();

                String createdLabel = "-";
                if (createdAt is Timestamp) {
                  final d = createdAt.toDate();
                  createdLabel =
                      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF9E1B4F).withOpacity(0.10),
                    ),
                    boxShadow: AppTheme.cardShadow(opacity: 0.06),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        context.read<AppState>().openOrderSmart(doc.id, null);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF9E1B4F,
                                ).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.package,
                                color: Color(0xFF9E1B4F),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.orderNumberLabel(
                                      doc.id.substring(0, 6),
                                    ),
                                    style: AppTheme.body(
                                      color: AppTheme.textDark,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _orderStatusPill(status),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.itemsCountLabel(items.length),
                                        style: AppTheme.caption(
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    createdLabel,
                                    style: AppTheme.caption(
                                      color: AppTheme.muted,
                                    ),
                                  ),

                                  if (carrier.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.carrierLabel(carrier),
                                      style: AppTheme.caption(
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],

                                  if (trackingNumber.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.trackingLabel(trackingNumber),
                                      style: AppTheme.caption(
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                  if (carrier.isNotEmpty &&
                                      trackingNumber.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        final url = _buildTrackingUrl(
                                          carrier,
                                          trackingNumber,
                                        );
                                        if (url.isNotEmpty) {
                                          await launchUrl(
                                            Uri.parse(url),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      child: Text(
                                        l10n.trackShipmentButton,
                                        style:
                                            AppTheme.caption(
                                              color: Colors.blue,
                                            ).copyWith(
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "₺${total.toStringAsFixed(0)}",
                                  style: AppTheme.body(
                                    color: AppTheme.textDark,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReturnsSection(
    BuildContext context,
    String businessId, {
    bool showHeader = true,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(l10n.returnRequestsTitle, style: AppTheme.h2()),
          const SizedBox(height: 10),
        ],

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _returnsStream,

          builder: (context, snapshot) {
            debugPrint(
              "🔄 RETURNS "
              "state=${snapshot.connectionState} "
              "hasData=${snapshot.hasData} "
              "docs=${snapshot.data?.docs.length} "
              "error=${snapshot.error}",
            );
            if (snapshot.hasError) {
              return _emptyBox(l10n.errorOccurred(snapshot.error.toString()));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final returns =
                snapshot.data?.docs.map(OrderReturnRecord.fromDoc).toList() ??
                [];
            debugPrint("📦 RETURN COUNT = ${returns.length}");
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (returns.isEmpty)
                    Text(
                      l10n.noReturnsYet,
                      style: AppTheme.body(color: AppTheme.muted),
                    )
                  else
                    ...returns.map(
                      (record) => OrderReturnCard(
                        record: record,
                        isSeller: true,
                        isBuyer: false,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      final businessId = appState.businessId;

      if (businessId != null) {
        _ensureSubMerchant(businessId);
      }
    });
  }

  // =========================
  // 🛒 PRODUCTS
  // =========================
  Widget _buildProductsSection(
    BuildContext context,
    String businessId, {
    bool showTitle = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final service = ProductService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================
        // 🔥 HEADER + CTA
        // =====================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (showTitle)
              Text(l10n.productsTitle, style: AppTheme.h2())
            else
              const SizedBox.shrink(),

            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics, color: AppTheme.textDark),
                  onPressed: () {
                    // TODO: analytics page
                  },
                ),
                const SizedBox(width: 6),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107), // 🔥 طلایی
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus),
                  label: Text(l10n.addButton),
                  onPressed: () {
                    context.read<AppState>().openAddProduct();
                  },
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // =====================
        // 📊 QUICK STATS
        // =====================
        StreamBuilder<List<Product>>(
          stream: service.getProducts(businessId),
          builder: (context, snapshot) {
            debugPrint(
              "📊 STATS "
              "state=${snapshot.connectionState} "
              "hasData=${snapshot.hasData} "
              "count=${snapshot.data?.length}",
            );
            final products = snapshot.data ?? [];

            final total = products.length;
            final lowStock = products.where((p) => p.isLowStock).length;
            final avgStrength = products.isEmpty
                ? 0
                : products
                          .map((p) => calculateProductStrength(p))
                          .reduce((a, b) => a + b) ~/
                      products.length;

            final shippable = products.where((p) => p.isShippable).length;
            final withKdv = products.where((p) => p.kdvRate != null).length;

            return Column(
              children: [
                Row(
                  children: [
                    _statBox(l10n.totalLabel, total.toString()),
                    const SizedBox(width: 8),
                    _statBox(
                      l10n.lowStockLabel,
                      lowStock.toString(),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _statBox(l10n.strengthLabel, "$avgStrength%"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statBox(l10n.shippableLabel, shippable.toString()),
                    const SizedBox(width: 8),
                    _statBox(l10n.withKdvLabel, withKdv.toString()),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 14),

        // =====================
        // 📡 PRODUCTS LIST
        // =====================
        StreamBuilder<List<Product>>(
          stream: service.getProducts(businessId),
          builder: (context, snapshot) {
            debugPrint(
              "📦 PRODUCTS "
              "state=${snapshot.connectionState} "
              "hasData=${snapshot.hasData} "
              "count=${snapshot.data?.length}",
            );
            if (snapshot.hasError) {
              return Text(l10n.errorOccurred(snapshot.error.toString()));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return _emptyBox(l10n.noProductsYet);
            }

            return Column(
              children: products.map<Widget>((p) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductCardDashboard(product: p, businessId: businessId),

                    const SizedBox(height: 8),

                    // ✅ NEW: tax + shipping + origin summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (p.kdvRate != null)
                                _chip(
                                  l10n.kdvRateLabel(
                                    p.kdvRate!.toStringAsFixed(0),
                                  ),
                                ),

                              if (p.taxIncluded == true)
                                _chip(l10n.kdvIncludedLabel),

                              if (p.originCity != null &&
                                  p.originCity!.trim().isNotEmpty)
                                _chip(l10n.fromLabel(p.originCity!)),

                              if (p.allowReturns)
                                _chip(
                                  l10n.returnsLabel(
                                    (p.returnWindowDays ?? 14).toString(),
                                  ),
                                ),

                              if (p.allowPickup) _chip(l10n.pickupLabel),

                              if (p.allowSameDay) _chip(l10n.sameDayLabel),
                            ],
                          ),

                          const SizedBox(height: 10),

                          _buildShippingInfo(context, p),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _statBox(String title, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.2)),
          boxShadow: AppTheme.cardShadow(opacity: 0.08),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTheme.h2(
                color: color ?? AppTheme.textDark,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: AppTheme.caption()),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.06),
    );
  }

  Widget _buildShippingInfo(BuildContext context, Product p) {
    final l10n = AppLocalizations.of(context)!;
    final mode = p.shippingMode;
    final freeThreshold = p.freeShippingThreshold;

    List<String> parts = [];

    // =====================
    // 🚚 SHIPPING COST
    // =====================
    if (mode == "free_shipping" || mode == "seller_absorbs") {
      parts.add(l10n.freeShippingLabel);
    } else if (mode == "fixed_price" && p.shippingFee != null) {
      parts.add("₺${p.shippingFee}");
    } else {
      parts.add(l10n.shippingCalculatedLabel);
    }

    // =====================
    // 🎯 FREE SHIPPING CONDITION
    // =====================
    if (freeThreshold != null && freeThreshold > 0) {
      parts.add(l10n.freeOverLabel("₺$freeThreshold"));
    }

    // =====================
    // ⚡ DELIVERY TIME
    // =====================
    if (p.preparationDays != null && p.maxDeliveryDays != null) {
      parts.add(
        l10n.deliveryDaysRangeLabel(
          p.preparationDays.toString(),
          p.maxDeliveryDays.toString(),
        ),
      );
    }

    // =====================
    // 📦 SPECIAL FLAGS
    // =====================
    if (p.isFragile == true) {
      parts.add(l10n.fragileLabel);
    }

    if (p.isOversize == true) {
      parts.add(l10n.oversizeLabel);
    }

    if (p.originCity != null && p.originCity!.trim().isNotEmpty) {
      parts.add(l10n.originLabel(p.originCity!));
    }

    if (p.allowedCarrierCodes.isNotEmpty) {
      parts.add(
        l10n.carriersCountLabel(p.allowedCarrierCodes.length.toString()),
      );
    }

    if (p.kdvRate != null) {
      parts.add(l10n.kdvRateLabel(p.kdvRate!.toStringAsFixed(0)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: parts.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(e, style: AppTheme.caption(color: Colors.blue)),
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}
