import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/models/product_media.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/common/smart_video_preview.dart';
import 'package:barky_matches_fixed/ui/product/seller_profile_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final ValueChanged<Product> onAddToBasket;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onAddToBasket,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _currentIndex = 0;
  bool _showAdded = false;

  Future<void> _handleAdd() async {
    if (_showAdded) return;
    final product = widget.product;
    widget.onAddToBasket(product);
    HapticFeedback.lightImpact();
    setState(() => _showAdded = true);
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) setState(() => _showAdded = false);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final l10n = AppLocalizations.of(context)!;
    final hasDiscount =
        product.salePrice != null &&
        product.salePrice! > 0 &&
        product.salePrice! < product.price;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      bottomNavigationBar: _bottomBar(product, l10n),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(child: _imageSlider(product)),
                  if (product.media.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(product.media.length, (i) {
                          final active = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF9E1B4F)
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      debugPrint(
                        'PRODUCT_DETAIL_SELLER_ROW_TAP: '
                        'sellerId=${product.businessId}, '
                        'sellerName=${product.businessName}',
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerProfilePage(
                            sellerId: product.businessId,
                            sellerName: product.businessName,
                            onAddToBasket: widget.onAddToBasket,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF9E1B4F,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFF9E1B4F),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.sellerLabel,
                                  style: AppTheme.caption(
                                    color: AppTheme.muted,
                                  ),
                                ),
                                if ((product.businessName ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    product.businessName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 18),
                  Text(
                    product.name,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.h2(weight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (hasDiscount)
                        Text(
                          "₺${product.customerReferencePrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        "₺${product.customerPrice.toStringAsFixed(2)}",
                        style: AppTheme.h1(
                          color: const Color(0xFF9E1B4F),
                          weight: FontWeight.w900,
                        ),
                      ),
                      if (hasDiscount)
                        _pill(
                          "-${product.discountPercent}%",
                          Icons.local_offer_outlined,
                          const Color(0xFFE53935),
                          const Color(0xFFFFEBEE),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusPills(product, l10n),
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Text(
                      AppLocalizations.of(context)!.productDetails,
                      style: AppTheme.h3(weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.description,
                      style: AppTheme.body(
                        color: AppTheme.textDark,
                      ).copyWith(height: 1.55),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _specRow(l10n.categoryLabel, product.category),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSlider(Product product) {
    if (product.media.isEmpty) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 44),
        ),
      );
    }

    return PageView.builder(
      itemCount: product.media.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (_, i) {
        final media = product.media[i];
        if (media.type == 'video') {
          final videoUrl = _resolveVideoUrl(media);
          if (videoUrl != null) {
            return ColoredBox(
              color: Colors.white,
              child: SmartVideoPreview(
                videoUrl: videoUrl,
                thumbnail: _isUsableUrl(media.thumbnailUrl)
                    ? media.thumbnailUrl
                    : null,
              ),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 58, 12, 22),
          child: CachedNetworkImage(
            imageUrl: media.originalUrl,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image_outlined, size: 44),
          ),
        );
      },
    );
  }

  List<Widget> _statusPills(Product product, AppLocalizations l10n) {
    final items = <Widget>[];

    if (product.shippingMode == 'free_shipping' ||
        product.shippingMode == 'seller_absorbs' ||
        product.shippingFee == 0) {
      items.add(_pill(l10n.freeCargoLabel, Icons.local_shipping_outlined));
    } else if (product.shippingFee != null) {
      items.add(
        _pill(
          l10n.cargoPriceLabel('₺${product.shippingFee!.toStringAsFixed(0)}'),
          Icons.local_shipping_outlined,
        ),
      );
    } else if (product.shippingMode == 'carrier_calculated') {
      items.add(
        _pill(l10n.cargoCalculatedLabel, Icons.local_shipping_outlined),
      );
    }

    if (product.maxDeliveryDays != null) {
      items.add(
        _pill(
          l10n.daysLabel(product.maxDeliveryDays.toString()),
          Icons.schedule_outlined,
          const Color(0xFF558B2F),
          const Color(0xFFF1F8E9),
        ),
      );
    }

    items.add(
      _pill(
        product.stock > 0 ? l10n.inStockLabel : l10n.outOfStockLabel,
        product.stock > 0 ? Icons.inventory_2_outlined : Icons.block_outlined,
        product.stock > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        product.stock > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      ),
    );

    if (product.kdvRate != null) {
      items.add(
        _pill(
          l10n.vatRateLabel(product.kdvRate!.toStringAsFixed(0)),
          Icons.receipt_long_outlined,
        ),
      );
    }
    if (product.taxIncluded == true) {
      items.add(_pill(l10n.vatIncludedLabel, Icons.check_circle_outline));
    }
    if ((product.originCity ?? '').trim().isNotEmpty) {
      items.add(_pill(product.originCity!, Icons.location_on_outlined));
    }
    if (product.freeShippingThreshold != null &&
        product.freeShippingThreshold! > 0) {
      items.add(
        _pill(
          l10n.freeOverLabel(
            '₺${product.freeShippingThreshold!.toStringAsFixed(0)}',
          ),
          Icons.savings_outlined,
        ),
      );
    }
    return items;
  }

  Widget _pill(
    String text,
    IconData icon, [
    Color color = const Color(0xFF9E1B4F),
    Color background = const Color(0xFFF9EDF2),
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTheme.caption(color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: AppTheme.caption(color: AppTheme.muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTheme.body(weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final value = url.trim();
    return value.isNotEmpty &&
        (value.startsWith('http://') || value.startsWith('https://'));
  }

  String? _resolveVideoUrl(ProductMedia media) {
    if (_isUsableUrl(media.playbackUrl)) return media.playbackUrl!.trim();
    if (_isUsableUrl(media.originalUrl)) return media.originalUrl.trim();
    return null;
  }

  Widget _bottomBar(Product product, AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: product.stock > 0 && !_showAdded ? _handleAdd : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Row(
                key: ValueKey(_showAdded),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showAdded ? Icons.check_rounded : Icons.add_shopping_cart,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showAdded
                        ? l10n.addedToCart
                        : '${l10n.addToCartButton} • ₺${product.customerPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
