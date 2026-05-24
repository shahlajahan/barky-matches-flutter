import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/firestore_recovery.dart';
import 'package:barky_matches_fixed/services/firestore_readiness_gate.dart';

class OffersManager {
  static List<Map<String, dynamic>> _offers = [];
  static bool _offersLoaded = false;
  static bool _offersLoading = false;
  static bool _offersInitialized = false;

  static int get offerCount => _offers.length;
  static final ValueNotifier<int> offersVersion =
    ValueNotifier<int>(0);
  static Future<void> loadOffersOnce({
    bool startupReady = true,
    bool forceRefresh = false,
    FirestoreRecoveryScope recoveryScope = FirestoreRecoveryScope.startup,
  }) async {
    if (!startupReady) {
      debugPrint('OFFERS EARLY SKIPPED');
      _offersLoading = false;
      _offersLoaded = false;
      _offersInitialized = false;
      return;
    }

    if (_offersLoading) return;
    if (_offersInitialized && _offersLoaded && !forceRefresh) return;

    _offersLoading = true;
    debugPrint('OFFERS LOAD AFTER STARTUP');
    if (forceRefresh) {
      debugPrint('OFFERS FORCE REFRESH');
      _offersLoaded = false;
      _offersInitialized = false;
    }
    debugPrint("🔥 LOAD OFFERS (clean mode)");

    try {
      Future<QuerySnapshot<Map<String, dynamic>>> fetchOffers() {
        debugPrint('OFFERS QUERY START');
        return FirebaseFirestore.instance
            .collection('offers')
            .get(); // ❗ بدون source forcing
      }

      final snapshot = await fetchOffers();
      debugPrint('OFFERS QUERY RESULT COUNT: ${snapshot.docs.length}');
      _offers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _offersLoaded = true;
      _offersInitialized = true;
      debugPrint('OFFERS LOADED SUCCESSFULLY');
      debugPrint("✅ OFFERS LOADED: ${_offers.length}");
      offersVersion.value++;
    } catch (e) {
      debugPrint("❌ loadOffersOnce error: $e");

      if (FirestoreRecovery.isConnectivityError(e)) {
        debugPrint(
          '🌐 FIRESTORE GATE DEGRADED → offers scope=${recoveryScope.name}',
        );
      }

      _offers = [];
      _offersLoaded = false;
      _offersInitialized = false;
    } finally {
      _offersLoading = false;
    }
  }

  static Widget _buildCTAButton(
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F).withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF9E1B4F).withOpacity(0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E1B4F).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTheme.bodyMedium().copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.88),
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: const Color(0xFF9E1B4F).withOpacity(0.65),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildBadge(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTheme.caption().copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  static Widget buildOffersSection(BuildContext context, bool? isPremium) {
    return RepaintBoundary(child: _OffersContent(isPremium: isPremium));
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

  static Widget _buildOfferCard(
    BuildContext context,
    Map<String, dynamic> offer,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bool isPremiumOnly = offer['isPremiumOnly'] == true;
    final String? logo =
        (offer['logoUrl'] != null &&
            offer['logoUrl'].toString().trim().isNotEmpty)
        ? offer['logoUrl'].toString()
        : offer['imageUrl']?.toString();

    final String title = (offer['title']?.toString().trim().isNotEmpty ?? false)
        ? offer['title'].toString().trim()
        : l10n.offerFallbackTitle;

    final String provider =
        (offer['provider']?.toString().trim().isNotEmpty ?? false)
        ? offer['provider'].toString().trim()
        : l10n.offerFallbackProvider;

    final String? code = offer['code']?.toString();
    final bool isSponsored = offer['isSponsored'] == true;
    final num? discount = offer['discount'] as num?;
    final bool hasCode = code != null && code.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          _handleOfferTap(context, offer);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD54F), Color(0xFFFFC107), Color(0xFFFFA000)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),

            child: Column(
              mainAxisSize: MainAxisSize.min, // 🔥 مهم
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacer(),

                /// 🔝 TOP ROW (BADGES + LOGO)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (isSponsored) _buildBadge(l10n.offerHotDeal),

                          if (isPremiumOnly)
                            _buildBadge(l10n.offerPremiumBadge),
                        ],
                      ),
                    ),

                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: (logo != null && logo.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: logo,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.white24),
                                errorWidget: (_, __, ___) => const Icon(
                                  LucideIcons.store,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                LucideIcons.store,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                /// 🏷 TITLE
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium().copyWith(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                /// 🏪 PROVIDER
                Row(
                  children: [
                    Icon(
                      LucideIcons.store,
                      size: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption().copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6), // 🔥 جایگزین Expanded
                /// 🔻 BOTTOM
                Row(
                  children: [
                    if (discount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.offerDiscountPercent(discount.toString()),
                          style: AppTheme.caption().copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.85),
                          ),
                        ),
                      ),

                    if (discount != null) const SizedBox(width: 6),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasCode ? l10n.offerUnlock : l10n.offerView,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.caption().copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    final l10n = AppLocalizations.of(context)!;
    final isPremiumOnly = offer['isPremiumOnly'] ?? false;
    final appState = Provider.of<AppState>(context, listen: false);

    final isGold = appState.isGold;
    final isPremium =
        appState.subscription.plan == SubscriptionPlan.premium &&
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
          title: Text(l10n.offerPremiumRequiredTitle),
          content: Text(l10n.offerPremiumRequiredMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.offerCancel),
            ),

            // 🔥 UPGRADE BUTTON
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                final appState = Provider.of<AppState>(context, listen: false);

                // 🟡 حالت 1: Guest → برو Login
                if (appState.isGuest) {
                  Navigator.pushNamed(context, '/auth');
                  return;
                }

                // 🟢 حالت 2: Logged ولی Free → برو Upgrade
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradePage()),
                );
              },
              child: Text(l10n.offerUpgrade),
            ),
          ],
        ),
      );

      return; // ⛔ خیلی مهم
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.offerUnlockingMessage),
        duration: Duration(milliseconds: 800),
      ),
    );

    final url = offer['url']?.toString();
    final insta = offer['instagram']?.toString();
    final whatsapp = offer['whatsapp']?.toString();
    final code = offer['code']?.toString();
    final priority = offer['ctaPriority']?.toString();

    // شمارش تعداد CTA های موجود
    final hasMultipleCTA =
        (url != null && url.isNotEmpty ? 1 : 0) +
        (insta != null && insta.isNotEmpty ? 1 : 0) +
        (whatsapp != null && whatsapp.isNotEmpty ? 1 : 0);

    // اگر بیشتر از یک CTA داشت → Bottom Sheet
    if (hasMultipleCTA > 1) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        barrierColor: Colors.black.withOpacity(0.28),
        builder: (_) {
          return SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// handle
                    Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    /// title area
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9E1B4F).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
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
                                l10n.offerChooseContinueTitle,
                                style: AppTheme.bodyMedium().copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withOpacity(0.92),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.offerChooseContinueSubtitle,
                                style: AppTheme.caption().copyWith(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (url != null && url.isNotEmpty)
                      _buildCTAButton(
                        l10n.offerOpenWebsite,
                        LucideIcons.globe,
                        () async {
                          Navigator.pop(context);
                          _openUrl(url);

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
                        },
                      ),

                    if (insta != null && insta.isNotEmpty)
                      _buildCTAButton(
                        l10n.offerInstagram,
                        LucideIcons.instagram,
                        () async {
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
                            } catch (e) {
                              debugPrint("⚠️ clickCount update failed: $e");
                            }

                            await _trackClick(offer, "instagram");
                          });
                        },
                      ),

                    if (whatsapp != null && whatsapp.isNotEmpty)
                      _buildCTAButton(
                        l10n.offerWhatsApp,
                        LucideIcons.messageCircle,
                        () async {
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
                            } catch (e) {
                              debugPrint("⚠️ clickCount update failed: $e");
                            }

                            await _trackClick(offer, "whatsapp");
                          });
                        },
                      ),

                    const SizedBox(height: 6),
                  ],
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.offerCodeCopied(code))));
        await _trackClick(offer, "copy_code");
        return;
      }

      debugPrint("⚠️ Offer has no CTA");
    } catch (e) {
      debugPrint("CTA error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.offerOpenError)));
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

class _OffersContent extends StatelessWidget {
  final bool? isPremium;

  const _OffersContent({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    debugPrint("🔥 PROJECT CHECK: ${FirebaseFirestore.instance.app.name}");

    /// 🛑 اگر هیچ آفر نداریم
    if (OffersManager._offers.isEmpty) {
      debugPrint("❌ NO OFFERS LOADED");
      return const SizedBox.shrink();
    }
    for (var o in OffersManager._offers) {
      debugPrint("🧪 FILTER INPUT: $o");
    }

    /// 🎯 FILTER
    final visibleOffersRaw = OffersManager._offers.where((offer) {
      final isPremiumOnly = offer['isPremiumOnly'] ?? false;

      if (isPremium == null) return true;
      if (!isPremium! && isPremiumOnly) return false;

      return true;
    }).toList();

    final visibleOffers = List<Map<String, dynamic>>.from(visibleOffersRaw);

    /// 🧪 DEBUG (خیلی مهم)
    debugPrint("🔥 TOTAL OFFERS: ${OffersManager._offers.length}");
    debugPrint("🔥 VISIBLE OFFERS: ${visibleOffers.length}");

    /// 🛑 اگر بعد از فیلتر چیزی نموند
    if (visibleOffers.isEmpty) {
      return const SizedBox.shrink();
    }

    /// 🎯 SORT (ads ranking engine)
    visibleOffers.sort((a, b) {
      final aSponsored = (a['isSponsored'] ?? false) ? 1 : 0;
      final bSponsored = (b['isSponsored'] ?? false) ? 1 : 0;

      final aScore = (a['priorityScore'] ?? 0) as num;
      final bScore = (b['priorityScore'] ?? 0) as num;

      final aClicks = (a['clickCount'] ?? 0) as num;
      final bClicks = (b['clickCount'] ?? 0) as num;

      final aWeight = (a['conversionWeight'] ?? 1) as num;
      final bWeight = (b['conversionWeight'] ?? 1) as num;

      final aTotal = (aSponsored * 1000) + (aScore * 10) + (aClicks * aWeight);
      final bTotal = (bSponsored * 1000) + (bScore * 10) + (bClicks * bWeight);

      return bTotal.compareTo(aTotal);
    });

    final bool hasMultiple = visibleOffers.length > 1;

    /// 🎬 UI
    return hasMultiple
        ? SizedBox(
            height: 168,
            child: CarouselSlider(
              options: CarouselOptions(
                height: 168,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                autoPlayAnimationDuration: const Duration(milliseconds: 700),
                viewportFraction: 1.0,
              ),
              items: visibleOffers
                  .map(
                    (offer) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: OffersManager._buildOfferCard(context, offer),
                    ),
                  )
                  .toList(),
            ),
          )
        : SizedBox(
            height: 168,
            child: OffersManager._buildOfferCard(context, visibleOffers.first),
          );
  }
}
