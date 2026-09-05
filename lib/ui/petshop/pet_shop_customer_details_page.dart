import 'package:cloud_firestore/cloud_firestore.dart';
import 'seller_product_availability.dart';
import 'package:flutter/material.dart';

import '../../services/marketplace_discovery_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/ui/petshop/all_products_page.dart';
import 'package:barky_matches_fixed/ui/petshop/pet_shop_profile_data.dart';

class PetShopCustomerDetailsPage extends StatefulWidget {
  const PetShopCustomerDetailsPage({
    super.key,
    required this.business,
    required this.onClose,
  });

  final BusinessCardData business;
  final VoidCallback onClose;

  @override
  State<PetShopCustomerDetailsPage> createState() =>
      _PetShopCustomerDetailsPageState();
}

class _PetShopCustomerDetailsPageState extends State<PetShopCustomerDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  PetShopProfileData get _shop => PetShopProfileData.fromMap(
    widget.business.id,
    widget.business.rawData ?? const {},
  );

  String get _productOwnerId {
    final explicit = widget.business.rawData?['_productOwnerId']
        ?.toString()
        .trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _shop.productOwnerId;
  }

  /// Buy Now stays hidden until this resolves, so a customer never sees an
  /// actionable button that would open an empty catalogue.
  SellerProductAvailability _productAvailability =
      SellerProductAvailability.unknown;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _resolveProductAvailability();
  }

  Future<void> _resolveProductAvailability() async {
    final result = await resolveSellerProductAvailability(_productOwnerId);
    if (!mounted) return;
    setState(() => _productAvailability = result);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buyNow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllProductsPage(
          initialSellerId: _productOwnerId,
          initialSellerName: widget.business.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * .92,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              _Header(business: widget.business, shop: _shop),
                              PositionedDirectional(
                                top: 12,
                                end: 12,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: widget.onClose,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ColoredBox(
                            color: Colors.white,
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              labelColor: AppTheme.primary,
                              unselectedLabelColor: Colors.black54,
                              indicatorColor: AppTheme.accent,
                              tabs: [
                                Tab(text: l10n.overviewTitle),
                                Tab(text: l10n.productsTitle),
                                Tab(text: l10n.reviewsTitle),
                                Tab(text: l10n.galleryTitle),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _OverviewTab(shop: _shop),
                                _ProductsTab(
                                  ownerId: _productOwnerId,
                                  onBuyNow: _buyNow,
                                ),
                                _ReviewsTab(businessId: widget.business.id),
                                _GalleryTab(urls: _shop.gallery),
                              ],
                            ),
                          ),
                          if (_productAvailability ==
                              SellerProductAvailability.available)
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                child: SizedBox(
                                  height: 54,
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _buyNow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(LucideIcons.shoppingBag),
                                    label: Text(
                                      l10n.buyNowButton,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.business, required this.shop});

  final BusinessCardData business;
  final PetShopProfileData shop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final image = shop.coverUrl ?? shop.logoUrl ?? '';
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _HeaderFallback(),
            )
          else
            const _HeaderFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          PositionedDirectional(
            start: 16,
            end: 54,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.h1(color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  business.address.isEmpty
                      ? l10n.locationNotAvailable
                      : business.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium(color: Colors.white70),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      business.rating?.toStringAsFixed(1) ?? '—',
                      style: AppTheme.caption(color: Colors.white),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      l10n.reviewsCountLabel(business.reviewsCount ?? 0),
                      style: AppTheme.caption(color: Colors.white70),
                    ),
                    if (business.isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        size: 17,
                        color: Colors.lightBlueAccent,
                      ),
                    ],
                  ],
                ),
                if (_todayHours(context, business.workingHours).isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _todayHours(context, business.workingHours),
                      style: AppTheme.caption(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _todayHours(BuildContext context, Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return '';
    const keys = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };
    final raw = hours[keys[DateTime.now().weekday]];
    if (raw is String) return raw;
    if (raw is Map) {
      if (raw['open'] == false) {
        return AppLocalizations.of(context)!.openStatusClosed;
      }
      return (raw['hours'] ?? '').toString();
    }
    return (hours['hours'] ?? '').toString();
  }
}

class _HeaderFallback extends StatelessWidget {
  const _HeaderFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF2D9E3),
    child: Center(
      child: Icon(
        LucideIcons.store,
        size: 52,
        color: AppTheme.primary.withValues(alpha: .55),
      ),
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.shop});
  final PetShopProfileData shop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: l10n.aboutTitle,
          child: Text(
            shop.description.isEmpty
                ? l10n.noShopDescriptionAvailable
                : shop.description,
            style: AppTheme.bodyMedium(color: Colors.black87),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: l10n.workingHoursTitle,
          child: _WorkingHours(hours: shop.workingHours),
        ),
        const SizedBox(height: 14),
        _Section(
          title: l10n.locationTitle,
          child: Text(
            shop.address.isEmpty ? l10n.locationNotAvailable : shop.address,
            style: AppTheme.bodyMedium(color: Colors.black87),
          ),
        ),
        if (shop.website != null || shop.instagram != null) ...[
          const SizedBox(height: 14),
          _Section(
            title: l10n.contactTitle,
            child: Text(
              [shop.website, shop.instagram]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join('\n'),
              style: AppTheme.bodyMedium(color: Colors.black87),
            ),
          ),
        ],
      ],
    );
  }
}

/// Marketplace Revision 43 §0.41 (Slice 7D) — the shop's product preview.
///
/// Previously a direct `businesses/{id}/products` stream filtered on
/// `isActive`/`moderationStatus`. Those two fields are not the publication
/// contract: a product also needs a valid compliance decision, a live pilot
/// approval, unexpired evidence, a matching business generation and a valid
/// pilot class, none of which a client can evaluate. This now asks the
/// server, scoped to this shop, and renders only what it returns.
class _ProductsTab extends StatefulWidget {
  const _ProductsTab({required this.ownerId, required this.onBuyNow});
  final String ownerId;
  final VoidCallback onBuyNow;

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  late final MarketplaceDiscoveryController _controller;

  @override
  void initState() {
    super.initState();
    // This private widget takes no service seam: the loading, race,
    // pagination and fail-closed behaviour it depends on is owned by
    // MarketplaceDiscoveryController and proven in that controller's own
    // tests, against a fake callable.
    _controller = MarketplaceDiscoveryController(pageSize: 8)
      ..addListener(_onChanged);
    if (widget.ownerId.isNotEmpty) {
      _controller.load(businessId: widget.ownerId);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _ProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new shop must not keep showing the previous shop's products. The
    // controller's own generation counter discards the superseded request.
    if (oldWidget.ownerId != widget.ownerId && widget.ownerId.isNotEmpty) {
      _controller.load(businessId: widget.ownerId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.ownerId.isEmpty) {
      return Center(child: Text(l10n.noProductsAvailableFromShop));
    }
    switch (_controller.status) {
      case DiscoveryStatus.idle:
      case DiscoveryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DiscoveryStatus.failed:
        return Center(child: Text(l10n.somethingWentWrong));
      case DiscoveryStatus.empty:
        return Center(child: Text(l10n.noProductsAvailableFromShop));
      case DiscoveryStatus.loaded:
        break;
    }
    final items = _controller.products;
    if (items.isEmpty) {
      return Center(child: Text(l10n.noProductsAvailableFromShop));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return TextButton(
            onPressed: widget.onBuyNow,
            child: Text(l10n.viewAllProducts),
          );
        }
        final product = items[index];
        return _Section(
          title: product.name,
          child: Text(
            '₺${product.customerPrice.toStringAsFixed(2)}',
            style: AppTheme.bodyMedium(color: AppTheme.primary),
          ),
        );
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Pet shop reviews failed: ${snapshot.error}');
          return Center(child: Text(l10n.reviewsCouldNotBeLoaded));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data!.docs;
        if (reviews.isEmpty) {
          return Center(child: Text(l10n.noReviewsYet));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = reviews[index].data();
            final text =
                (data['comment'] ?? data['review'] ?? data['text'] ?? '')
                    .toString();
            return _Section(
              title: '★ ${data['rating'] ?? '—'}',
              child: Text(text, style: AppTheme.bodyMedium()),
            );
          },
        );
      },
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (urls.isEmpty) return Center(child: Text(l10n.galleryNotAvailable));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryViewerPage(
              items: urls.map(MediaItem.fromUrl).toList(),
              initialIndex: index,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            urls[index],
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkingHours extends StatelessWidget {
  const _WorkingHours({this.hours});
  final Map<String, dynamic>? hours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (hours == null || hours!.isEmpty) {
      return Text(l10n.workingHoursNotAvailable);
    }
    if (hours!['hours'] is String) {
      return Text(hours!['hours'].toString());
    }
    return Column(
      children: hours!.entries.map((entry) {
        final value = entry.value is Map
            ? Map<String, dynamic>.from(entry.value)
            : null;
        final text = value == null
            ? entry.value.toString()
            : value['open'] == false
            ? l10n.openStatusClosed
            : (value['hours'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              Flexible(child: Text(text, textAlign: TextAlign.end)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppTheme.cardShadow(opacity: .06),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.h3()),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
