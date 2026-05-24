import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'pet_taxi_booking_detail_page.dart';
import 'pet_taxi_booking_page.dart';

class PetTaxiPage extends StatefulWidget {
  const PetTaxiPage({super.key});

  @override
  State<PetTaxiPage> createState() => _PetTaxiPageState();
}

class _PetTaxiPageState extends State<PetTaxiPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<BusinessCardData> _businesses = [];
  List<BusinessCardData> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .get();
      if (!mounted) return;

      final businesses =
          snapshot.docs
              .map((doc) => _mapPetTaxiBusiness(doc.id, doc.data()))
              .whereType<BusinessCardData>()
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _businesses = businesses;
        _filtered = businesses;
        _loading = false;
      });
      debugPrint('PetTaxiPage loaded businesses=${businesses.length}');
    } catch (e) {
      debugPrint('PetTaxiPage load error: ${e.toString()}');
      if (mounted) setState(() => _loading = false);
    }
  }

  BusinessCardData? _mapPetTaxiBusiness(String id, Map<String, dynamic> data) {
    final root = <String, dynamic>{...data, 'id': id};
    final sectorData = _map(root['sectorData']);
    final taxi = _map(
      sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
    );
    final raw = [
      root['sector'],
      root['sectors'],
      root['businessType'],
      root['category'],
      sectorData.keys.join(' '),
      sectorData.toString(),
    ].join(' ').toLowerCase();
    if (!raw.contains('pet_taxi') &&
        !raw.contains('pet taxi') &&
        !raw.contains('taxi')) {
      return null;
    }

    final profile = _map(root['profile']);
    final contact = _map(root['contact']);
    final compliance = _map(taxi['compliance']);
    final vehicle = _map(taxi['vehicle']);
    final media = _map(taxi['profileContent']);
    final name = _firstText([
      profile['displayName'],
      taxi['displayName'],
      root['businessName'],
      root['name'],
    ]);
    final city = contact['city']?.toString().trim() ?? '';
    final district = contact['district']?.toString().trim() ?? '';
    final address = _firstText([
      contact['addressLine'],
      [district, city].where((part) => part.isNotEmpty).join(', '),
    ]);

    return BusinessCardData(
      id: id,
      name: name.isNotEmpty ? name : 'Pet Taxi',
      city: city,
      district: district,
      address: address,
      specialties: const ['Pet Taxi', 'Safe Transport'],
      services: const ['One way', 'Round trip', 'Vet', 'Groomy', 'Hotel'],
      phone: contact['phone']?.toString(),
      whatsapp: contact['whatsapp']?.toString() ?? contact['phone']?.toString(),
      description: _firstText([
        taxi['description'],
        profile['description'],
        vehicle['vehicleType'],
      ]),
      isVerified: _map(root['verification'])['isVerified'] == true,
      status: root['status']?.toString() ?? 'approved',
      type: BusinessType.petTaxi,
      logoUrl: _firstText([
        profile['logoUrl'],
        taxi['logo'],
        media['clinicLogoUrl'],
      ]),
      rawData: {...root, 'petTaxiCompliance': compliance},
      data: root,
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final query = value.trim().toLowerCase();
      setState(() {
        _searchQuery = query;
        _filtered = _businesses.where((business) {
          final searchable = [
            business.name,
            business.city,
            business.district,
            business.address,
            business.description,
          ].join(' ').toLowerCase();
          return query.isEmpty || searchable.contains(query);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBusinesses,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Pet Taxi',
                style: AppTheme.h2().copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Book safe pet transportation with reviewed taxi businesses.',
                style: AppTheme.body(color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search taxi businesses',
                  prefixIcon: const Icon(LucideIcons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_filtered.isEmpty)
                _emptyState()
              else
                ..._filtered.map((business) => _businessCard(business)),
              
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Text(
        _searchQuery.isEmpty
            ? 'No pet taxi businesses are available yet.'
            : 'No pet taxi businesses match your search.',
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }

  Widget _businessCard(BusinessCardData business) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF9E1B4F).withOpacity(0.12),
                child: const Icon(LucideIcons.car, color: Color(0xFF9E1B4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        business.district,
                        business.city,
                      ].where((part) => part.isNotEmpty).join(', '),
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((business.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              business.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.calendarPlus, size: 18),
              label: const Text('Book Pet Taxi'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PetTaxiBookingPage(business: business),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.05),
    );
  }
}
