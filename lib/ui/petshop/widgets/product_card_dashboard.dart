import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/services/product_service.dart';

import 'package:barky_matches_fixed/ui/business/petshop/add_product_page.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:barky_matches_fixed/ui/common/smart_video_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:lucide_icons/lucide_icons.dart';

class ProductCardDashboard extends StatelessWidget {
  final Product product;
  final String businessId;

  const ProductCardDashboard({
    super.key,
    required this.product,
    required this.businessId,
  });

  // =====================
  // 🧠 STRENGTH
  // =====================
  double _calculateStrength(Product p) {
    double score = 0;

    if (p.name.trim().length >= 3) score += 20;
    if (p.description.trim().length >= 20) score += 20;
    if (p.media.isNotEmpty) score += 20;
    if (p.media.length >= 3) score += 10;
    if (p.price > 0) score += 15;
    if (p.stock > 0) score += 10;
    if (p.category != "general") score += 5;

    return score;
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final strength = _calculateStrength(p);

    final hasDiscount =
        p.salePrice != null && p.salePrice! < p.price;

    final displayPrice = p.finalPrice;

    final service = ProductService();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
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

          // =====================
          // 📸 MEDIA
          // =====================
          _buildMedia(context, p),

          const SizedBox(height: 10),

          // =====================
          // 📝 NAME + PRICE + BADGES
          // =====================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // NAME + META
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name.isNotEmpty ? p.name : "Unnamed Product",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.h3(weight: FontWeight.w700),
                    ),

                    const SizedBox(height: 4),

                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      Text("Barcode: ${p.barcode}",
                          style: AppTheme.caption()),

                    if (p.sku != null && p.sku!.isNotEmpty)
                      Text("SKU: ${p.sku}",
                          style: AppTheme.caption()),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // PRICE
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  if (hasDiscount)
                    Text(
                      "${p.price} ${p.currency}",
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                  Text(
                    "$displayPrice ${p.currency}",
                    style: AppTheme.h2(
                      color: const Color(0xFF9E1B4F),
                      weight: FontWeight.w900,
                    ),
                  ),

                  if (hasDiscount && p.discountPercent > 0)
                    Text(
                      "-${p.discountPercent}%",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // =====================
          // 🚀 BADGES
          // =====================
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (strength >= 80)
                _badge("🔥 Strong", Colors.green),

              if (p.stock > 0 && p.stock <= 3)
                _badge("⚡ Low Stock", Colors.red),

              if (hasDiscount)
                _badge("💸 Deal", Colors.orange),

              if (p.media.length >= 3)
                _badge("📸 Rich", Colors.blue),
            ],
          ),

          const SizedBox(height: 8),

          // =====================
          // 🚚 SHIPPING
          // =====================
          _buildShipping(p),

          const SizedBox(height: 8),

          // =====================
          // 📦 STOCK
          // =====================
          Row(
            children: [
              const Icon(LucideIcons.package, size: 14),
              const SizedBox(width: 6),
              Text("Stock: ${p.stock}", style: AppTheme.caption()),

              if (p.stock > 0 && p.stock <= 3)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text("⚠ Low",
                      style: TextStyle(color: Colors.red, fontSize: 11)),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // =====================
          // 🧠 STRENGTH BAR
          // =====================
          LinearProgressIndicator(
            value: strength / 100,
            minHeight: 6,
          ),

          const SizedBox(height: 10),

          // =====================
          // 🎯 ACTIONS
          // =====================
          Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.pencil),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddProductPage(
                        businessId: businessId,
                        existingProduct: p,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2),
                onPressed: () {
                  service.deleteProduct(businessId, p.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================
  // 📸 MEDIA
  // =====================
  Widget _buildMedia(BuildContext context, Product p) {
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
      itemBuilder: (_, i) {
        final m = p.media[i];
        final isVideo = m.type == "video";

        final hasPlayback =
            m.playbackUrl != null && m.playbackUrl!.trim().isNotEmpty;

        final hasThumb =
            m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty;

        final hasImage =
            m.originalUrl.trim().isNotEmpty;

        return GestureDetector(
          onTap: () {
            final safeMedia = p.media.where((media) {
              if (media.type == "video") {
                return media.playbackUrl != null &&
                    media.playbackUrl!.trim().isNotEmpty;
              }
              return media.originalUrl.trim().isNotEmpty;
            }).toList();

            if (safeMedia.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Media not ready yet")),
              );
              return;
            }

            final initialIndex = safeMedia.indexWhere((media) {
              if (media.type == "video" && isVideo) {
                return media.playbackUrl == m.playbackUrl;
              }
              return media.originalUrl == m.originalUrl;
            });

            final items = safeMedia.map((media) {
              return MediaItem(
                url: media.type == "video"
                    ? media.playbackUrl!
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
                  items: items,
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
                      child: hasPlayback
                          ? SmartVideoPreview(
                              videoUrl: m.playbackUrl!,
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

  // =====================
  // 🚚 SHIPPING
  // =====================
  Widget _buildShipping(Product p) {
    final parts = <String>[];

    if (p.shippingMode == "free_shipping") {
      parts.add("Free shipping");
    } else if (p.shippingFee != null) {
      parts.add("₺${p.shippingFee}");
    }

    if (p.freeShippingThreshold != null) {
      parts.add("Free over ₺${p.freeShippingThreshold}");
    }

    if (p.preparationDays != null &&
        p.maxDeliveryDays != null) {
      parts.add("${p.preparationDays}-${p.maxDeliveryDays} days");
    }

    return Wrap(
      spacing: 6,
      children: parts
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e, style: AppTheme.caption()),
              ))
          .toList(),
    );
  }

  // =====================
  // 🏷 BADGE
  // =====================
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
}