import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/petshop/seller_offers_page.dart';
import 'package:barky_matches_fixed/ui/business/petshop/add_product_page.dart';
import 'package:barky_matches_fixed/services/product_service.dart';

import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:barky_matches_fixed/ui/common/smart_video_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barky_matches_fixed/models/product_media.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
//import 'package:barky_matches_fixed/ui/petshop/widgets/checkout_button.dart';
import 'package:barky_matches_fixed/ui/cart/cart_page.dart';

enum ProductCardMode {
  dashboard,
  customerList,
}

class ProductCardShared extends StatelessWidget {
  final Product product;
  final ProductCardMode mode;

  const ProductCardShared({
    super.key,
    required this.product,
    required this.mode,
  });

  bool get isDashboard => mode == ProductCardMode.dashboard;

  double calculateProductStrength(Product p) {
    double score = 0;

    if (p.name.trim().length >= 3) score += 20;
    if (p.description.trim().length >= 20) score += 20;
    if (p.media.length >= 1) score += 20;
    if (p.media.length >= 3) score += 10;
    if (p.price > 0) score += 15;
    if (p.stock > 0) score += 10;
    if (p.category != "general") score += 5;

    return score;
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

  @override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  if (mode == ProductCardMode.customerList) {
  return _buildCompactCard(context);
}
  final appState = context.watch<AppState>();
  final strength = calculateProductStrength(product);

  final hasDiscount =
      product.salePrice != null &&
      product.salePrice! > 0 &&
      product.salePrice! < product.price;

  final displayPrice = product.finalPrice;
  final discountAmount =
      hasDiscount ? (product.price - product.salePrice!) : 0.0;

  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: strength >= 80
          ? const Color(0xFF9E1B4F).withOpacity(0.03)
          : Colors.white,
      border: Border.all(
        color: const Color(0xFF9E1B4F).withOpacity(0.2),
      ),
      boxShadow: AppTheme.cardShadow(),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaSection(context, product),
        const SizedBox(height: 10),

        // =====================
        // NAME + PRICE
        // =====================
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.isNotEmpty
                        ? product.name
                        : l10n.unnamedProduct,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.h3(
                      color: AppTheme.textDark,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (product.barcode != null &&
                      product.barcode!.isNotEmpty)
                    Text(
                      l10n.barcodeLabel(product.barcode!),
                      style: AppTheme.caption(
                        color: AppTheme.muted,
                      ),
                    ),

                  if (product.sku != null &&
                      product.sku!.isNotEmpty)
                    Text(
                      l10n.skuLabel(product.sku!),
                      style: AppTheme.caption(
                        color: AppTheme.muted,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDiscount)
                  Text(
                    "${product.price.toStringAsFixed(0)} ${product.currency}",
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),

                Text(
                  "${displayPrice.toStringAsFixed(0)} ${product.currency}",
                  style: AppTheme.h2(
                    color: const Color(0xFF9E1B4F),
                    weight: FontWeight.w900,
                  ),
                ),

                if (hasDiscount)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "-${product.discountPercent}%",
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // =====================
        // DESCRIPTION
        // =====================
        if (product.description.trim().isNotEmpty)
          Text(
  product.description,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AppTheme.caption(color: AppTheme.muted),
),
        const SizedBox(height: 8),

        // =====================
        // BADGES
        // =====================
       Wrap(
  spacing: 4,
  runSpacing: 4,
  children: [
    if (hasDiscount)
      _badge(l10n.dealBadge, Colors.orange),

    if (product.stock <= 3)
      _badge(l10n.lowStockBadge, Colors.red),
  ],
),

        // =====================
        // DISCOUNT INFO
        // =====================
        if (hasDiscount) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.saveAmountLabel("₺${discountAmount.toStringAsFixed(0)}"),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (product.salePrice != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.salePriceLabel(
                      "${product.salePrice!.toStringAsFixed(0)} ${product.currency}",
                    ),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],

        // =====================
        // SHIPPING INFO
        // =====================
        const SizedBox(height: 8),
       // _buildShippingInfo(product),

        const SizedBox(height: 8),

        // =====================
        // STOCK
        // =====================
        Row(
          children: [
            Icon(
              LucideIcons.package,
              size: 14,
              color: AppTheme.muted,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.stockLabel(product.stock.toString()),
              style: AppTheme.caption(
                color: AppTheme.textDark.withOpacity(0.8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
const Spacer(),
        if (isDashboard)
          _buildDashboardActions(context)
        else
          _buildCustomerActions(context),
      ],
    ),
  );
}

Widget _buildCustomerActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: () => _addToCart(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart, size: 18),
                  SizedBox(width: 6),
                  Text(l10n.addToCartButton),
                ],
              ),
            ),
          ),
        ),
      ),

      const SizedBox(width: 8),

      Expanded(
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: () => _buyNow(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flash_on, size: 18),
                  SizedBox(width: 6),
                  Text(l10n.buyNowButton),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
void _addToCart(BuildContext context) {
  final appState = context.read<AppState>();
  final l10n = AppLocalizations.of(context)!;

  final cartItem = CartItem(
    productId: product.id,
    product: product,
    shopId: product.businessId,
    allowedCarrierCodes: product.allowedCarrierCodes, 
    name: product.name,
    price: product.finalPrice,
    quantity: 1,
    imageUrl: product.media.isNotEmpty
        ? product.media.first.originalUrl
        : null,
  );
debugPrint("🟡 PRODUCT carriers: ${product.allowedCarrierCodes}");
debugPrint("🟢 CART carriers: ${cartItem.allowedCarrierCodes}");
  appState.addToCart(cartItem);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.addedToCart)),
  );
}

void _buyNow(BuildContext context) {
  final appState = context.read<AppState>();

  final cartItem = CartItem(
    productId: product.id,
    product: product,
    shopId: product.businessId,
    name: product.name,
    price: product.finalPrice,
    quantity: 1,
    allowedCarrierCodes: product.allowedCarrierCodes,
    imageUrl: product.media.isNotEmpty
        ? product.media.first.originalUrl
        : null,
  );

  debugPrint("🔴 BUY NOW PRODUCT carriers: ${product.allowedCarrierCodes}");
  debugPrint("🔴 BUY NOW CART ITEM carriers: ${cartItem.allowedCarrierCodes}");

  appState.removeFromCart(product.id); // ✅ مهم
  appState.addToCart(cartItem);        // ✅ مهم

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CartPage(),
    ),
  );
}

  Widget _buildShippingInfo(BuildContext context, Product p) {
  final l10n = AppLocalizations.of(context)!;
  final List<String> parts = [];

  // 🚚 DEBUG درست
  debugPrint("🚚 PRODUCT carriers: ${p.allowedCarrierCodes}");

  // 🚚 shipping mode / fee
  if (p.shippingMode == "free_shipping" || p.shippingMode == "seller_absorbs") {
    parts.add(l10n.freeShippingLabel);
  } else if (p.shippingMode == "fixed_price" && p.shippingFee != null) {
    parts.add(l10n.cargoLabel("₺${p.shippingFee!.toStringAsFixed(0)}"));
  } else if (p.shippingMode == "carrier_calculated") {
    parts.add(l10n.cargoCalculatedLabel);
  }

  // 🚛 carrier names
  if (p.allowedCarrierCodes != null && p.allowedCarrierCodes!.isNotEmpty) {
    final carriers = p.allowedCarrierCodes!.join(", ");
    parts.add(l10n.carrierLabel(carriers));
  }

  // ⏱ delivery window
  if (p.preparationDays != null && p.maxDeliveryDays != null) {
    parts.add(
      l10n.deliveryDaysRangeLabel(
        p.preparationDays.toString(),
        p.maxDeliveryDays.toString(),
      ),
    );
  } else if (p.maxDeliveryDays != null) {
    parts.add(l10n.daysLabel(p.maxDeliveryDays.toString()));
  }

  // 🎁 free shipping threshold
  if (p.freeShippingThreshold != null && p.freeShippingThreshold! > 0) {
    parts.add(
      l10n.freeOverLabel("₺${p.freeShippingThreshold!.toStringAsFixed(0)}"),
    );
  }

  if (parts.isEmpty) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: parts.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.10),
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

Widget _buildDiscountInfo(BuildContext context, Product p) {
  final l10n = AppLocalizations.of(context)!;
  final hasDiscount =
      p.salePrice != null && p.salePrice! > 0 && p.salePrice! < p.price;

  if (!hasDiscount) return const SizedBox.shrink();

  final discountAmount = p.price - p.salePrice!;
  final discountPercent = p.discountPercent;

  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.saveAmountLabel("₺${discountAmount.toStringAsFixed(0)}"),
          style: const TextStyle(
            color: Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (discountPercent > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "-$discountPercent%",
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
}

  Widget _buildDashboardActions(BuildContext context) {
    final appState = context.read<AppState>();
    final businessId = appState.businessId;
    final service = ProductService();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.pencil, color: Colors.black87),
          onPressed: () {
            if (businessId == null) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddProductPage(
                  businessId: businessId,
                  existingProduct: product,
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(LucideIcons.trash2, color: Colors.red),
          onPressed: () {
            if (businessId == null) return;
            service.deleteProduct(businessId, product.id);
          },
        ),
      ],
    );
  }

   

  Widget _buildMediaSection(BuildContext context, Product p) {
  if (p.media.isEmpty) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade300,
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported),
      ),
    );
  }

  return SizedBox(
   height: 90,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: p.media.length,
      itemBuilder: (_, index) {
        final m = p.media[index];
        final isVideo = m.type == "video";

        final resolvedVideoUrl = isVideo ? _resolveVideoUrl(m) : null;
        final hasVideo = resolvedVideoUrl != null;
        final hasThumb = _isUsableUrl(m.thumbnailUrl);
        final hasImage = _isUsableUrl(m.originalUrl);

        return GestureDetector(
          onTap: () {
            final safeMedia = p.media.where((media) {
              if (media.type == "video") {
                return _resolveVideoUrl(media) != null;
              }
              return _isUsableUrl(media.originalUrl);
            }).toList();

            if (safeMedia.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.mediaNotReadyYet)),
              );
              return;
            }

            final initialIndex = safeMedia.indexWhere((media) {
              if (media.type == "video" && isVideo) {
                return _resolveVideoUrl(media) == resolvedVideoUrl;
              }
              return media.originalUrl == m.originalUrl;
            });

            final mediaItems = safeMedia.map((media) {
              final videoUrl = _resolveVideoUrl(media);
              return MediaItem(
                url: media.type == "video"
                    ? videoUrl!
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
                  initialIndex: initialIndex < 0 ? 0 : initialIndex,
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
                  if (isVideo)
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: hasVideo
                          ? SmartVideoPreview(
                              videoUrl: resolvedVideoUrl!,
                              thumbnail: hasThumb ? m.thumbnailUrl : null,
                            )
                          : hasThumb
                              ? CachedNetworkImage(
                                  imageUrl: m.thumbnailUrl!,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 110,
                                  height: 110,
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.videocam_off,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                    )
                  else
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: m.originalUrl,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                    ),

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

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
  Widget _buildCompactCard(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final hasDiscount =
      product.salePrice != null &&
      product.salePrice! > 0 &&
      product.salePrice! < product.price;

  final price = product.finalPrice;

  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      boxShadow: AppTheme.cardShadow(),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖼 IMAGE
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: product.media.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.media.first.originalUrl,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.grey.shade300),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📛 NAME
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 4),

              // 💰 PRICE
              Text(
                "₺${price.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 6),

              // 🛒 BUTTON
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () => _addToCart(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(l10n.addButton, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
