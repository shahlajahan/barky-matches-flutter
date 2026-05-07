import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/product/product_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerProfilePage extends StatelessWidget {
  final String sellerId;
  final String? sellerName;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
    this.sellerName,
  });

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(sellerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data?.data() as Map<String, dynamic>? ?? {};

                  final profile =
                      (data['profile'] as Map<String, dynamic>?) ?? {};
                  final contact =
                      (data['contact'] as Map<String, dynamic>?) ?? {};
final verification =
    (data['verification'] as Map<String, dynamic>?) ?? {};

    final phone = contact['phone']?.toString();
    
final whatsapp = contact['whatsapp']?.toString();
final email = contact['email']?.toString();

final isVerified = verification['isVerified'] == true;
                  final businessDisplayName =
                      (profile['businessName'] ??
                              profile['name'] ??
                              sellerName ??
                              'Seller')
                          .toString();

                  final coverUrl = (
  profile['coverUrl'] ??
  profile['coverImage'] ??
  profile['bannerUrl'] ??
  data['coverUrl'] // ✅ fallback به root
)?.toString();

final logoUrl = (
  profile['logoUrl'] ??
  profile['imageUrl'] ??
  data['logoUrl'] // ✅ fallback به root
);
print("🔥 COVER URL: $coverUrl");
print("🔥 LOGO URL: $logoUrl");

                  final city = (contact['city'] ?? profile['city'])?.toString();
                  final district =
                      (contact['district'] ?? profile['district'])?.toString();

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isUsableUrl(coverUrl))
  CachedNetworkImage(
    imageUrl: coverUrl!,
    fit: BoxFit.cover,
  )
else
  Container(
    color: const Color(0xFFF3F3F3),
    child: Center(
      child: Icon(
        Icons.storefront_outlined,
        size: 40,
        color: Colors.grey.shade500,
      ),
    ),
  ),
                      Container(
                        color: Colors.black.withOpacity(0.18),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 56, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: _SellerLogo(url: logoUrl),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
  children: [
    Expanded(
      child: Text(
        businessDisplayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.h2(
          color: Colors.white,
          weight: FontWeight.w900,
        ),
      ),
    ),
    if (isVerified) ...[
      const SizedBox(width: 6),
      const Icon(Icons.verified, color: Colors.blue, size: 18),
    ]
  ],
),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFFFC107),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '4.6',
                                              style: AppTheme.body(
                                                color: Colors.white,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Seller rating',
                                              style: AppTheme.caption(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((city ?? '').isNotEmpty ||
                                            (district ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            [
                                              if ((district ?? '').isNotEmpty)
                                                district,
                                              if ((city ?? '').isNotEmpty) city,
                                            ].join(' / '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTheme.caption(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 14),
                

                // summary cards
                StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collectionGroup('products')
      .where('isActive', isEqualTo: true)
      .where('businessId', isEqualTo: sellerId)
      .snapshots(),
  builder: (context, snapshot) {

    // 🔥 DEBUG START
    print("🟡 SellerProfilePage QUERY RUN");
    print("👉 sellerId = $sellerId");
    print("👉 hasError = ${snapshot.hasError}");
    print("👉 hasData = ${snapshot.hasData}");

    if (snapshot.hasError) {
      print("🔥 FIRESTORE ERROR: ${snapshot.error}");
    }

    if (snapshot.hasData) {
      print("📦 DOC COUNT: ${snapshot.data!.docs.length}");
    }
    // 🔥 DEBUG END
                    final docs = snapshot.data?.docs ?? [];
                    final products = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Product.fromJson(doc.id, data);
                    }).toList();

                    final totalProducts = products.length;
                    final inStockCount =
                        products.where((p) => p.stock > 0).length;
                    final discountedCount = products
                        .where((p) =>
                            p.salePrice != null &&
                            p.salePrice! > 0 &&
                            p.salePrice! < p.price)
                        .length;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Products',
                              value: totalProducts.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'In stock',
                              value: inStockCount.toString(),
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: 'Deals',
                              value: discountedCount.toString(),
                              icon: Icons.local_offer_outlined,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),
                

                // about seller
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(sellerId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data =
                        snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final profile =
                        (data['profile'] as Map<String, dynamic>?) ?? {};
                    final contact =
                        (data['contact'] as Map<String, dynamic>?) ?? {};
final sectorData =
    (data['sectorData'] as Map<String, dynamic>?) ?? {};

final petshopData =
    (sectorData['petshop'] as Map<String, dynamic>?) ?? {};

final petshopProfile =
    (petshopData['profile'] as Map<String, dynamic>?) ?? {};

final nestedProfile =
    (profile['profile'] as Map<String, dynamic>?) ?? {};

print("🔥 PROFILE RAW: ${data['profile']}");
print("🔥 SECTOR DATA RAW: ${data['sectorData']}");
print("🔥 PETSHOP PROFILE RAW: $petshopProfile");

String? about;

if ((profile['description'] ?? '').toString().trim().isNotEmpty) {
  about = profile['description'].toString().trim();
} else if ((profile['about'] ?? '').toString().trim().isNotEmpty) {
  about = profile['about'].toString().trim();
} else if ((profile['bio'] ?? '').toString().trim().isNotEmpty) {
  about = profile['bio'].toString().trim();
} else if ((nestedProfile['bio'] ?? '').toString().trim().isNotEmpty) {
  about = nestedProfile['bio'].toString().trim();
} else if ((petshopProfile['bio'] ?? '').toString().trim().isNotEmpty) {
  about = petshopProfile['bio'].toString().trim();
}
       

                    final phone = contact['phone']?.toString();
                    final whatsapp = contact['whatsapp']?.toString();
                    final website = contact['website']?.toString();
                    final email = contact['email']?.toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Seller',
                              style: AppTheme.h3(weight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              (about != null && about.trim().isNotEmpty)
                                  ? about
                                  : 'This seller has not added a profile description yet.',
                              style: AppTheme.body(
                                color: (about != null && about.trim().isNotEmpty)
                                    ? AppTheme.textDark
                                    : AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    children: [
      if ((phone ?? '').isNotEmpty)
        Expanded(
          child: _ActionButton(
            icon: Icons.call,
            label: "Call",
            color: Colors.green,
            onTap: () => _openUrl("tel:$phone"),
          ),
        ),

      if ((phone ?? '').isNotEmpty &&
          (whatsapp ?? '').isNotEmpty)
        const SizedBox(width: 8),

      if ((whatsapp ?? '').isNotEmpty)
        Expanded(
          child: _ActionButton(
            icon: Icons.chat,
            label: "WhatsApp",
            color: Colors.green.shade700,
            onTap: () =>
                _openUrl("https://wa.me/$whatsapp"),
          ),
        ),

      if ((email ?? '').isNotEmpty)
        const SizedBox(width: 8),

      if ((email ?? '').isNotEmpty)
        Expanded(
          child: _ActionButton(
            icon: Icons.email,
            label: "Email",
            color: Colors.blue,
            onTap: () =>
                _openUrl("mailto:$email"),
          ),
        ),
    ],
  ),
),

const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if ((phone ?? '').isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.phone_outlined,
                                    label: phone!,
                                  ),
                                if ((email ?? '').isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.mail_outline,
                                    label: email!,
                                  ),
                                if ((website ?? '').isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.language_outlined,
                                    label: website!,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Seller Products',
                        style: AppTheme.h3(weight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text(
                        'Newest first',
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('products')
                .where('isActive', isEqualTo: true)
                .where('businessId', isEqualTo: sellerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Error loading seller products: ${snapshot.error}',
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data!.docs;

              final products = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Product.fromJson(doc.id, data);
              }).toList()
                ..sort((a, b) {
                  final aa = a.createdAt?.millisecondsSinceEpoch ?? 0;
                  final bb = b.createdAt?.millisecondsSinceEpoch ?? 0;
                  return bb.compareTo(aa);
                });

              if (products.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('This seller has no active products'),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return _SellerProductCard(product: product);
                    },
                    childCount: products.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final v = url.trim();
    return v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));
  }
}

class _SellerLogo extends StatelessWidget {
  final String? url;

  const _SellerLogo({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null &&
        url!.trim().isNotEmpty &&
        (url!.startsWith('http://') || url!.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
      );
    }

    return Container(
  color: const Color(0xFFF5F5F5),
  child: Center(
    child: Text(
      "KP",
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade600,
      ),
    ),
  ),
);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9E1B4F)),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.h3(
              weight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.caption(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.caption(
                color: AppTheme.textDark,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerProductCard extends StatelessWidget {
  final Product product;

  const _SellerProductCard({
    required this.product,
  });

  bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final v = url.trim();
    return v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.salePrice != null &&
        product.salePrice! > 0 &&
        product.salePrice! < product.price;

    final firstMedia =
        product.media.isNotEmpty ? product.media.first.originalUrl : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Container(
                    height: 145,
                    width: double.infinity,
                    color: Colors.white,
                    child: _isUsableUrl(firstMedia)
                        ? CachedNetworkImage(
                            imageUrl: firstMedia!,
                            fit: BoxFit.contain,
                          )
                        : Container(
                            color: const Color(0xFFF3F3F3),
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "-${product.discountPercent}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        weight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          "4.5",
                          style: AppTheme.caption(
                            weight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "(128)",
                          style: AppTheme.caption(color: AppTheme.muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (hasDiscount)
                      Text(
                        "₺${product.price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      "₺${product.finalPrice.toStringAsFixed(0)}",
                      style: AppTheme.h3(
                        color: const Color(0xFF9E1B4F),
                        weight: FontWeight.w900,
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 4),
    Flexible(
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  ],
)
      ),
    );
  }
}