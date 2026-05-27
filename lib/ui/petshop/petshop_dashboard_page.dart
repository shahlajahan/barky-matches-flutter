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
import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barky_matches_fixed/ui/common/smart_video_preview.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/ui/petshop/widgets/product_card_dashboard.dart';

import 'package:barky_matches_fixed/ui/seller/seller_orders_page.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:barky_matches_fixed/models/order_return.dart';
import 'package:barky_matches_fixed/ui/returns/order_return_card.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:barky_matches_fixed/ui/business/petshop/edit_petshop_profile_page.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_functions/cloud_functions.dart';

class PetShopDashboardPage extends StatefulWidget {
  const PetShopDashboardPage({super.key});

  @override
  State<PetShopDashboardPage> createState() =>
      _PetShopDashboardPageState();
}
class _PetShopDashboardPageState extends State<PetShopDashboardPage> {
  
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final businessId = appState.businessId;
    if (appState.businessSubPage == BusinessSubPage.addProduct) {
  return AddProductPage(
    businessId: businessId!,
  );
}

    debugPrint("🧠 DASHBOARD BUILD → businessId=$businessId");

    if (businessId == null) {
      return Center(
        child: Text(l10n.businessNotFound),
      );
    }

    return Container(
  color: AppTheme.bg,
  child: SafeArea(
    
    child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
  _buildRevenueCard(context, businessId),
  const SizedBox(height: 20),
  _buildProfileSection(context, businessId),
  const SizedBox(height: 20),
  _buildOrdersSection(context, businessId),
  const SizedBox(height: 20),
  _buildReturnsSection(context, businessId),
  const SizedBox(height: 20),
  _buildCatalogStrengthSection(context, businessId),
  const SizedBox(height: 20),
  _buildProductsSection(context, businessId),
  const SizedBox(height: 20),
  _buildOffersSection(context),
],
    ),
      ),
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

  final functions =
      FirebaseFunctions.instanceFor(region: 'europe-west3');

  final res = await functions
      .httpsCallable('createSubMerchant')
      .call({
    "businessId": businessId,
  });

  debugPrint("🔥 subMerchant created: ${res.data}");
}

Widget _buildProfileSection(BuildContext context, String businessId) {
  final l10n = AppLocalizations.of(context)!;
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .snapshots(),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.shopProfileTitle, style: AppTheme.h2()),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPetShopProfilePage(
                          businessId: businessId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.editProfile),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              shopName,
              style: AppTheme.h3(weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
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
                    "${l10n.locationLabel} ${[
                      if (district.isNotEmpty) district,
                      if (city.isNotEmpty) city,
                    ].join(' / ')}",
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
    stream: FirebaseFirestore.instance
        .collection("sellerOrders")
        .where("shopId", isEqualTo: businessId)
        .snapshots(includeMetadataChanges: false),
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
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
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
        Text(
          title,
          style: const TextStyle(color: Colors.white70),
        ),
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
Widget _buildOrdersSection(BuildContext context, String businessId) {
  final l10n = AppLocalizations.of(context)!;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recentOrdersTitle, style: AppTheme.h2()),
          const SizedBox(height: 4),
          Text(
            l10n.latestOrdersSubtitle,
            style: AppTheme.caption(color: AppTheme.muted),
          ),
        ],
      ),
    ),
    TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerOrdersPage(
              businessId: businessId,
            ),
          ),
        );
      },
      child: Text(l10n.viewAllButton),
    ),
  ],
),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
    .collection("sellerOrders")
    .where("shopId", isEqualTo: businessId)
    .orderBy("createdAt", descending: true)
    .limit(5)
    .snapshots(),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
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

    final shipping = (data["shipping"] as Map<String, dynamic>?) ?? {};
final carrier = (shipping["carrier"] ?? "").toString();
final trackingNumber = (shipping["trackingNumber"] ?? "").toString();

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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF9E1B4F).withOpacity(0.10),
        ),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailPage(sellerOrderId: doc.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withOpacity(0.08),
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
                      l10n.orderNumberLabel(doc.id.substring(0, 6)),
                      style: AppTheme.body(
    color: AppTheme.textDark,
  ).copyWith(
    fontWeight: FontWeight.w700,
  ),
),
const SizedBox(height: 6),
Row(
  children: [
    _orderStatusPill(status),
    const SizedBox(width: 8),
    Text(
      l10n.itemsCountLabel(items.length),
      style: AppTheme.caption(color: AppTheme.muted),
    ),
  ],
),
const SizedBox(height: 6),
Text(
  createdLabel,
  style: AppTheme.caption(color: AppTheme.muted),
),

if (carrier.isNotEmpty) ...[
  const SizedBox(height: 6),
  Text(
    l10n.carrierLabel(carrier),
    style: AppTheme.caption(color: AppTheme.textDark),
  ),
],

if (trackingNumber.isNotEmpty) ...[
  const SizedBox(height: 4),
  Text(
    l10n.trackingLabel(trackingNumber),
    style: AppTheme.caption(color: AppTheme.textDark),
  ),
],
if (carrier.isNotEmpty && trackingNumber.isNotEmpty) ...[
  const SizedBox(height: 6),
  GestureDetector(
    onTap: () async {
      final url = _buildTrackingUrl(carrier, trackingNumber);
      if (url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    },
    child: Text(
      l10n.trackShipmentButton,
      style: AppTheme.caption(
        color: Colors.blue,
      ).copyWith(
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
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
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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

Widget _buildReturnsSection(BuildContext context, String businessId) {
  final l10n = AppLocalizations.of(context)!;

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('order_returns')
        .where('businessId', isEqualTo: businessId)
        .orderBy('requestedAt', descending: true)
        .limit(5)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _emptyBox(l10n.errorOccurred(snapshot.error.toString()));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final returns = snapshot.data?.docs
              .map(OrderReturnRecord.fromDoc)
              .toList() ??
          [];

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.returnRequestsTitle, style: AppTheme.h2()),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
  // 🧠 CATALOG STRENGTH
  // =========================
  Widget _buildCatalogStrengthSection(BuildContext context, String businessId) {
    final l10n = AppLocalizations.of(context)!;
    final service = ProductService();

    return StreamBuilder<List<Product>>(
      stream: service.getProducts(businessId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyBox(l10n.catalogStrengthUnavailable);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];
        final result = _calculateCatalogStrength(context, products);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: result.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: result.color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.catalogStrengthTitle,
                style: AppTheme.h2(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: result.percent / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(100),
                      valueColor: AlwaysStoppedAnimation<Color>(result.color),
                     backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${result.percent}%",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: result.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.message,
                style: TextStyle(
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // 🛒 PRODUCTS
  // =========================
  Widget _buildProductsSection(BuildContext context, String businessId) {
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
          Text(l10n.productsTitle, style: AppTheme.h2()),

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
          )
        ],
      ),

      const SizedBox(height: 12),

      // =====================
      // 📊 QUICK STATS
      // =====================
      StreamBuilder<List<Product>>(
        stream: service.getProducts(businessId),
        builder: (context, snapshot) {

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
        _statBox(l10n.lowStockLabel, lowStock.toString(), color: Colors.orange),
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
        ProductCardDashboard(
          product: p,
          businessId: businessId,
        ),

        const SizedBox(height: 8),

        // ✅ NEW: tax + shipping + origin summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.kdvRate != null)
                    _chip(l10n.kdvRateLabel(p.kdvRate!.toStringAsFixed(0))),

                  if (p.taxIncluded == true)
                    _chip(l10n.kdvIncludedLabel),

                  if (p.originCity != null &&
                      p.originCity!.trim().isNotEmpty)
                    _chip(l10n.fromLabel(p.originCity!)),

                  if (p.allowReturns)
                    _chip(l10n.returnsLabel((p.returnWindowDays ?? 14).toString())),

                  if (p.allowPickup)
                    _chip(l10n.pickupLabel),

                  if (p.allowSameDay)
                    _chip(l10n.sameDayLabel),
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


Widget _badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

  Widget _buildMediaSection(BuildContext context, Product p) {
  final l10n = AppLocalizations.of(context)!;
  if (p.media.isEmpty) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade700,
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white70),
      ),
    );
  }

  return SizedBox(
    height: 110,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: p.media.length,
      itemBuilder: (_, index) {
        final m = p.media[index];
        final isVideo = m.type == "video";

        final hasPlayback =
            m.playbackUrl != null && m.playbackUrl!.isNotEmpty;

        return GestureDetector(
          onTap: () {
            // ✅ فقط مدیاهای safe رو می‌فرستیم
            final safeMedia = p.media.where((media) {
              if (media.type == "video") {
                return media.playbackUrl != null &&
                    media.playbackUrl!.isNotEmpty;
              }
              return media.originalUrl.isNotEmpty;
            }).toList();

            if (safeMedia.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.mediaNotReadyYet)),
              );
              return;
            }

            final mediaItems = safeMedia.map((media) {
              return MediaItem(
                url: media.type == "video"
                    ? media.playbackUrl! // ✅ اینجا safe شده
                    : media.originalUrl,
                type: media.type == "video"
                    ? MediaType.video
                    : MediaType.image,
              );
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GalleryViewerPage(
                  items: mediaItems,
                  initialIndex: 0, // 🔥 مهم
                ),
              ),
            );
          },

          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // =====================
                  // 🎥 VIDEO
                  // =====================
                  if (isVideo)
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: hasPlayback
                          ? SmartVideoPreview(
                              videoUrl: m.playbackUrl!,
                              thumbnail: m.thumbnailUrl,
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    )

                  // =====================
                  // 🖼 IMAGE
                  // =====================
                  else
                    CachedNetworkImage(
                      imageUrl: m.originalUrl,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),

                  // ▶️ ICON
                  if (isVideo)
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _statBox(String title, String value, {Color? color}) {
  return Expanded(
              child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF9E1B4F).withOpacity(0.2),
        ),
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
          Text(
            title,
            style: AppTheme.caption(),
          ),
        ],
      ),
    ),
  );
}

  // =========================
  // 🎯 OFFERS
  // =========================
  Widget _buildOffersSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.offersTitle, style: AppTheme.h2()),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            debugPrint("🎯 CREATE OFFER CLICKED");
          },
          child: Text(l10n.createOfferButton),
        )
      ],
    );
  }

  // =========================
  // 🔧 HELPERS
  // =========================
  bool _isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.webm') ||
        u.contains('.m4v') ||
        u.contains('.hevc');
  }

  Widget _buildImagePreview(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.grey.shade800),
        Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;

            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoPreview(BuildContext context, String url) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black87),
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 56,
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.videoLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }

  _CatalogStrengthResult _calculateCatalogStrength(BuildContext context, List<Product> products) {
    final l10n = AppLocalizations.of(context)!;
    if (products.isEmpty) {
      return _CatalogStrengthResult(
        percent: 10,
        label: l10n.catalogStrengthWeakLabel,
        color: Colors.redAccent,
        message: l10n.catalogStrengthAddItemsMessage,
      );
    }

    int score = 0;
    int maxScore = 0;

    final sample = products.take(8).toList();

    for (final p in sample) {
      maxScore += 100;

      if (p.name.trim().isNotEmpty) score += 20;
      if (p.description.trim().length >= 20) score += 20;
      if (p.price > 0) score += 15;
      if (p.stock > 0) score += 10;
      if (p.media.isNotEmpty) score += 20;
      if (p.media.length >= 3) score += 10;
      if (p.category.trim().isNotEmpty && p.category != "general") {
        score += 5;
      }
    }

    final percent =
        maxScore == 0 ? 0 : ((score / maxScore) * 100).round();

    if (percent < 40) {
      return _CatalogStrengthResult(
        percent: percent,
        label: l10n.catalogStrengthWeakLabel,
        color: Colors.redAccent,
        message: l10n.catalogStrengthWeakDetailsMessage,
      );
    }

    if (percent < 75) {
      return _CatalogStrengthResult(
        percent: percent,
        label: l10n.catalogStrengthMediumLabel,
        color: Colors.orange,
        message: l10n.catalogStrengthMediumMessage,
      );
    }

    return _CatalogStrengthResult(
      percent: percent,
      label: l10n.catalogStrengthStrongLabel,
      color: Colors.green,
      message: l10n.catalogStrengthStrongMessage,
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
  parts.add(l10n.carriersCountLabel(p.allowedCarrierCodes.length.toString()));
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
          child: Text(
            e,
            style: AppTheme.caption(color: Colors.blue),
          ),
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
      style: AppTheme.caption(
        color: const Color(0xFF9E1B4F),
      ),
    ),
  );
}
}

class _CatalogStrengthResult {
  final int percent;
  final String label;
  final Color color;
  final String message;

  _CatalogStrengthResult({
    required this.percent,
    required this.label,
    required this.color,
    required this.message,
  });
}
