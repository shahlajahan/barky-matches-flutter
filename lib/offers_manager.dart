import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'upgrade_page.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';

class OffersManager {
  static List<Map<String, dynamic>> _offers = [];
  //static bool _loaded = false;

  static Future<void> loadOffersOnce() async {
debugPrint("🔥 TRYING TO LOAD OFFERS FROM FIRESTORE...");
   // if (_loaded) return;

    try {
      final snapshot =
          await FirebaseFirestore.instance
    .collection('offers')
    .get(const GetOptions(source: Source.server));

      _offers = snapshot.docs.map((doc) {
  final data = doc.data();
  data['id'] = doc.id; // 🔥 مهم
  return data;
}).toList();

      //_loaded = true;
      debugPrint('OffersManager - Loaded ${_offers.length} offers (once)');
    } catch (e) {
      debugPrint('OffersManager - Error loading offers: $e');

      // 🔥 TEST DATA WITH CTA
      _offers = [
        
        {
          'isPremiumOnly': true,
          'id': 'test_offer',
          'discount': 15,
          'provider': 'Ortakoy Pera',
          'code': 'TEST15',
          'url': 'https://google.com',
          'instagram': 'miacihan',
          'whatsapp': '5466577827',
          
        },
      ];
    }
  }
  static Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

static Widget _buildCTAButton(String text, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(text),
      ),
    ),
  );
}


  static Widget buildOffersSection(BuildContext context, bool? isPremium) {
    if (_offers.isEmpty) return const SizedBox.shrink();

    final visibleOffers = _offers.where((offer) {
  final isPremiumOnly = offer['isPremiumOnly'] ?? false;
final plan = "normal";
  // 🔥 guest → همه offer ها رو ببینه
  if (isPremium == null) return true;

  // 🔥 logged user
  if (!isPremium && isPremiumOnly) return false;

  return true;
}).toList();

    if (visibleOffers.isEmpty) return const SizedBox.shrink();

    final bool hasMultiple = visibleOffers.length > 1;

visibleOffers.sort((a, b) {
  final aSponsored = (a['isSponsored'] ?? false) ? 1 : 0;
  final bSponsored = (b['isSponsored'] ?? false) ? 1 : 0;

  final aScore = (a['priorityScore'] ?? 0) as num;
  final bScore = (b['priorityScore'] ?? 0) as num;

  final aClicks = (a['clickCount'] ?? 0) as num;
  final bClicks = (b['clickCount'] ?? 0) as num;

  final aWeight = (a['conversionWeight'] ?? 1) as num;
  final bWeight = (b['conversionWeight'] ?? 1) as num;

  final aTotal =
      (aSponsored * 1000) + (aScore * 10) + (aClicks * aWeight);
  final bTotal =
      (bSponsored * 1000) + (bScore * 10) + (bClicks * bWeight);

  return bTotal.compareTo(aTotal);
});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Special Offers',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: hasMultiple
              ? CarouselSlider(
                  options: CarouselOptions(
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 6),
                    viewportFraction: 0.92,
                    height: 90,
                  ),
                  items: visibleOffers
    .map<Widget>((offer) => _buildOfferCard(context, offer))
    .toList(),
                )
               : _buildOfferCard(context, visibleOffers.first),
        ),
      ],
    );
  }

  // 🔥 CTA HANDLERS
  static Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);

  debugPrint("👉 TRY OPEN URL: $url");

  final canLaunch = await canLaunchUrl(uri);
  debugPrint("👉 canLaunch = $canLaunch");

  if (canLaunch) {
   await launchUrl(uri, mode: LaunchMode.platformDefault);
    debugPrint("✅ URL OPENED");
  } else {
    debugPrint("❌ Cannot launch URL");
  }
}

  static Future<void> _openInstagram(String username) async {
  final uri = Uri.parse("https://instagram.com/$username");

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint("❌ Cannot open Instagram");
  }
}

  static Future<void> _openWhatsApp(String phone) async {
  final uri = Uri.parse("https://wa.me/$phone");

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint("❌ Cannot open WhatsApp");
  }
}

  static Widget _buildOfferCard(BuildContext context, Map<String, dynamic> offer) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _handleOfferTap(context, offer);
        },
        splashColor: Colors.black.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFFFC107),
                Color(0xFFFFA000),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // subtle light reflection
              Positioned(
                top: -10,
                left: -10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${offer['discount'] ?? 0}%",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            offer['provider'] ?? "",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Code: ${offer['code'] ?? '-'}",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ],
                ),
              ),

              // ─── BADGE SPONSORED ───────────────────────────────
              if (offer['isSponsored'] == true)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Sponsored",
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
static Future<void> _handleOfferTap(
 // debugPrint("👉 appState = $appState");
  BuildContext context,
  Map<String, dynamic> offer,
) async {
  // ✅ DEBUG + SnackBar فوری
  debugPrint("🔥 OFFER: $offer");
final isPremiumOnly = offer['isPremiumOnly'] ?? false;
  final appState = Provider.of<AppState>(context, listen: false);

final isGold = appState.isGold;
final isPremium = appState.subscription.plan == SubscriptionPlan.premium &&
                  appState.subscription.status.isActive;
  // ─── چک دسترسی پرمیوم (قبل از هر چیزی) ───────────────────────────────
  // فرض: plan از Provider.of<UserProvider>(context).plan یا مشابه میاد
  // اگر هنوز نداری، باید از بیرون پاس بدی یا از context بگیری
 // final appState = Provider.of<AppState>(context, listen: false);
//final plan = appState.subscriptionPlan.name; 

  if (isPremiumOnly && !isPremium && !isGold) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Premium Required"),
      content: const Text("This offer is only for premium members."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),

        // 🔥 UPGRADE BUTTON
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);

            final appState =
                Provider.of<AppState>(context, listen: false);

            // 🟡 حالت 1: Guest → برو Login
            if (appState.isGuest) {
              Navigator.pushNamed(context, '/auth'); 
              return;
            }

            // 🟢 حالت 2: Logged ولی Free → برو Upgrade
            Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const UpgradePage(),
  ),
);
          },
          child: const Text("Upgrade"),
        ),
      ],
    ),
  );

  return; // ⛔ خیلی مهم
}

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Opening offer..."),
      duration: Duration(milliseconds: 800),
    ),
  );

  final url = offer['url']?.toString();
  final insta = offer['instagram']?.toString();
  final whatsapp = offer['whatsapp']?.toString();
  final code = offer['code']?.toString();
  final priority = offer['ctaPriority']?.toString();

  // شمارش تعداد CTA های موجود
  final hasMultipleCTA = (url != null && url.isNotEmpty ? 1 : 0) +
      (insta != null && insta.isNotEmpty ? 1 : 0) +
      (whatsapp != null && whatsapp.isNotEmpty ? 1 : 0);

  // اگر بیشتر از یک CTA داشت → Bottom Sheet
  if (hasMultipleCTA > 1) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (url != null && url.isNotEmpty)
                  _buildCTAButton("Open Website", () async {
                    debugPrint("👉 WEBSITE BUTTON CLICKED");
                    Navigator.pop(context);

// 🔥 اول URL رو باز کن (بدون هیچ await قبلش)
//_openUrl(url);

// 🔥 بقیه رو async کن
Future.microtask(() async {
  try {
    if (offer['id'] != null) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({
        "clickCount": FieldValue.increment(1),
      });
    }
  } catch (e) {
    debugPrint("⚠️ clickCount update failed: $e");
  }

  await _trackClick(offer, "url");
});

                    await _openUrl(url);

// 🔥 tracking رو async جدا کن
_trackClick(offer, "url");
                  }),

                if (insta != null && insta.isNotEmpty)
                  _buildCTAButton("Instagram", () async {
                    Navigator.pop(context);

_openInstagram(insta);

Future.microtask(() async {
  try {
    if (offer['id'] != null) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({
        "clickCount": FieldValue.increment(1),
      });
    }
  } catch (e) {}

  await _trackClick(offer, "instagram");
});

                    await _openInstagram(insta);
                    await _trackClick(offer, "instagram");
                  }),

                if (whatsapp != null && whatsapp.isNotEmpty)
                  _buildCTAButton("WhatsApp", () async {
                    Navigator.pop(context);

_openWhatsApp(whatsapp);

Future.microtask(() async {
  try {
    if (offer['id'] != null) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({
        "clickCount": FieldValue.increment(1),
      });
    }
  } catch (e) {}

  await _trackClick(offer, "whatsapp");
});

                    await _openWhatsApp(whatsapp);
                    await _trackClick(offer, "whatsapp");
                  }),
              ],
            ),
          ),
        );
      },
    );
    return;
  }

  // ────────────────────────────────────────────────
  // حالت تک CTA یا اولویت‌دار
  // ────────────────────────────────────────────────

  try {
    // اولویت‌دار
    if (priority == "url" && url != null && url.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openUrl(url);
      await _trackClick(offer, "url");
      return;
    }

    if (priority == "instagram" && insta != null && insta.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openInstagram(insta);
      await _trackClick(offer, "instagram");
      return;
    }

    if (priority == "whatsapp" && whatsapp != null && whatsapp.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openWhatsApp(whatsapp);
      await _trackClick(offer, "whatsapp");
      return;
    }

    // Fallback ها
    if (url != null && url.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openUrl(url);
      await _trackClick(offer, "url");
      return;
    }

    if (insta != null && insta.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openInstagram(insta);
      await _trackClick(offer, "instagram");
      return;
    }

    if (whatsapp != null && whatsapp.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection("offers")
          .doc(offer['id'])
          .update({"clickCount": FieldValue.increment(1)});
      await _openWhatsApp(whatsapp);
      await _trackClick(offer, "whatsapp");
      return;
    }

    // آخرین راه → کپی کد
    if (code != null && code.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Code copied: $code")),
      );
      await _trackClick(offer, "copy_code");
      return;
    }

    debugPrint("⚠️ Offer has no CTA");
  } catch (e) {
    debugPrint("CTA error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error opening offer")),
    );
  }
}
static Future<void> _trackClick(
  Map<String, dynamic> offer,
  String action,
) async {
  try {
    await FirebaseFirestore.instance.collection("offer_clicks").add({
      "offerTitle": offer['title'],
      "provider": offer['provider'],
      "action": action,
      "timestamp": FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint("Tracking error: $e");
  }
}
}