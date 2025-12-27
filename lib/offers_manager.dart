import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:math';

class OffersManager {
  static List<Map<String, dynamic>> _offers = [];

  static Future<void> loadOffers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('offers').get();
      _offers = snapshot.docs.map((doc) => doc.data()).toList();
      print('OffersManager - Loaded ${_offers.length} offers');
    } catch (e) {
      print('OffersManager: Error loading offers: $e');
      _offers = [
        {
          'title': 'Test Offer',
          'imageUrl': 'https://images.unsplash.com/photo-1507146426996-ef05306b995a',
          'discount': 10,
          'provider': 'Ortakoy Pera',
          'code': 'TEST123',
          'isPremiumOnly': false,
        },
      ];
    }
  }

  static Widget buildOffersSection(bool isPremium) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('offers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load offers.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }
        _offers = snapshot.data?.docs.map((doc) => doc.data() as Map<String, dynamic>).toList() ?? _offers;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 90),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                  child: Text(
                    'Special Offers${isPremium ? " (Premium Boosted)" : ""}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: CarouselSlider(
                    options: CarouselOptions(
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 5),
                      enlargeCenterPage: true,
                      viewportFraction: 0.85,
                      aspectRatio: 16 / 9,
                      height: 70,
                      enableInfiniteScroll: true,
                    ),
                    items: _offers.map((offer) {
                      if (!isPremium && (offer['isPremiumOnly'] ?? false)) return null;
                      return ClipRect(
                        child: Card(
                          color: Colors.white.withOpacity(0.8),
                          margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: SizedBox(
                              width: 150,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    child: SizedBox(
                                      height: 25,
                                      width: double.infinity,
                                      child: Image.network(
                                        offer['imageUrl'] ?? 'https://images.unsplash.com/photo-1507146426996-ef05306b995a',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Image load error for ${offer['title']}: $error');
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Center(
                                              child: Text(
                                                'Image not available',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 4,
                                                  color: Colors.black54,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      (loadingProgress.expectedTotalBytes ?? 1)
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Flexible(
                                    child: Text(
                                      '${offer['discount'] ?? 0}% off ${offer['provider'] ?? ''}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      'code: ${offer['code']?.substring(0, min<int>(offer['code']?.length ?? 0, 5)) ?? 'N/A'}',
                                      style: GoogleFonts.poppins(fontSize: 4),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  SizedBox(
                                    height: 10,
                                    width: 35,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/offer_details', arguments: {
                                          'title': offer['title'],
                                          'discount': offer['discount'],
                                          'code': offer['code'],
                                          'provider': offer['provider'],
                                          'imageUrl': offer['imageUrl'] ?? 'https://images.unsplash.com/photo-1507146426996-ef05306b995a',
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFC107),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                        textStyle: GoogleFonts.poppins(fontSize: 4),
                                      ),
                                      child: const Text('Explore'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).whereType<Widget>().toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static List<Map<String, dynamic>> get offers => _offers;
}