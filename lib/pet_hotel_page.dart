import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart' as app;
import 'ui/business/business_card_data.dart';
import 'ui/business/pet_hotel/pet_hotel_booking_page.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card_data.dart';

class PetHotelPage extends StatefulWidget {
  const PetHotelPage({super.key});

  @override
  State<PetHotelPage> createState() => _PetHotelPageState();
}

class _PetHotelPageState extends State<PetHotelPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<VetCardData> _hotels = [];
List<VetCardData> _filteredHotels = [];

  @override
  void initState() {
    super.initState();
    _loadHotelsFromFirestore();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHotelsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .get();

      if (!mounted) return;

      final hotels = snapshot.docs
          .map((doc) => _mapHotelBusiness(doc.id, doc.data()))
          .whereType<VetCardData>()
          .toList();

      hotels.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _hotels = hotels;
        _filteredHotels = hotels;
        _loading = false;
      });

      debugPrint('PET HOTEL PAGE LOADED businesses=${hotels.length}');
    } catch (e) {
      debugPrint('PET HOTEL PAGE LOAD ERROR $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  VetCardData? _mapHotelBusiness(String id, Map<String, dynamic> data) {
    final root = <String, dynamic>{...data, 'id': id};
    if (!_isHotelBusiness(root)) return null;

    final profile = _map(root['profile']);
    final contact = _map(root['contact']);
    final sectorData = _map(root['sectorData']);
    final hotel = _map(
      sectorData['pet_hotel'] ?? sectorData['hotel'] ?? sectorData['petHotel'],
    );
    final profileContent = _map(hotel['profileContent'] ?? hotel['content']);
    final socialMedia = _map(profileContent['socialMedia']);
    final services = _map(hotel['services']);

    final name = _firstText([
      profile['displayName'],
      profile['businessName'],
      hotel['displayName'],
      root['displayName'],
      root['businessName'],
      root['name'],
    ]);

    final description = _firstText([
      profileContent['bio'],
      profileContent['description'],
      hotel['description'],
      profile['description'],
      profile['bio'],
      root['description'],
    ]);

    final city = contact['city']?.toString().trim() ?? '';
    final district = contact['district']?.toString().trim() ?? '';
    final address = _firstText([
      contact['addressLine'],
      contact['address'],
      [district, city].where((item) => item.isNotEmpty).join(', '),
    ]);

    final serviceTitles = _serviceTitles([
      services['offeredServices'],
      services['services'],
      hotel['offeredServices'],
      hotel['amenities'],
      profile['tags'],
      root['tags'],
    ]);

    final ratingRaw = profile['rating'] ?? root['rating'];
    final reviewCountRaw =
        profile['reviewCount'] ??
        profile['reviewsCount'] ??
        root['reviewsCount'];

   return VetCardData(
    type: BusinessType.petHotel,
  id: id,

  name: name.isNotEmpty
      ? name
      : 'Pet Hotel',

  city: city,
  district: district,
  address: address,

  phone: contact['phone']?.toString(),

  whatsapp:
      contact['whatsapp']?.toString() ??
      contact['phone']?.toString(),

  specialties: serviceTitles.isNotEmpty
      ? serviceTitles
      : const ['Boarding'],

  services: serviceTitles,

  distanceKm: null,

  rating: ratingRaw is num
      ? ratingRaw.toDouble()
      : null,

  reviewsCount:
      reviewCountRaw is num
          ? reviewCountRaw.toInt()
          : 0,

  isPartner: true,

  workingHours: _workingHours(hotel),

  logoUrl: _firstText([
    profile['logoUrl'],
    profile['logo'],
    profileContent['clinicLogoUrl'],
    profileContent['logoUrl'],
    hotel['logo'],
    root['logoUrl'],
  ]),

  description: description,

  is24h: false,
  isEmergency: false,

  instagram:
      contact['instagram']?.toString() ??
      socialMedia['instagram']?.toString(),

  website:
      contact['website']?.toString() ??
      socialMedia['website']?.toString(),

  coverImageUrl: _firstText([
    root['coverImageUrl'],
  ]),

  sectorData: sectorData,

  rawData: root,
);
  }

  bool _isHotelBusiness(Map<String, dynamic> data) {
    final profile = _map(data['profile']);
    final sectorData = _map(data['sectorData']);
    final raw = [
      data['sector'],
      data['sectors'],
      data['businessType'],
      data['category'],
      data['type'],
      profile['categories'],
      profile['businessType'],
      profile['category'],
      profile['tags'],
      sectorData.keys.join(' '),
      sectorData.toString(),
    ].join(' ').toLowerCase();

    return raw.contains('pet_hotel') ||
        raw.contains('pet hotel') ||
        raw.contains('hotel') ||
        raw.contains('boarding') ||
        raw.contains('pansiyon');
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

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return <String>[];
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _serviceTitles(List<dynamic> values) {
    for (final value in values) {
      final items = _stringList(value);
      if (items.isNotEmpty) return items;
    }
    return const <String>['Standard Room', 'VIP Room', 'Daily Care'];
  }

  Map<String, String> _workingHours(Map<String, dynamic> hotel) {
    final workingHours = _map(hotel['workingHours']);
    final rawWorkingHours = workingHours['workingHours'];
    final map = <String, String>{};
    if (rawWorkingHours is Map) {
      rawWorkingHours.forEach((key, value) {
        map[key.toString()] = value.toString();
      });
    } else if (rawWorkingHours is String && rawWorkingHours.trim().isNotEmpty) {
      map['hours'] = rawWorkingHours.trim();
    }
    return map;
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final lower = query.toLowerCase().trim();

      setState(() {
        _searchQuery = lower;
        _filteredHotels = _hotels.where((business) {
          final searchable = [
            business.name,
            business.city,
            business.district,
            business.description,
            business.specialties.join(' '),
            business.services?.join(' ') ?? '',
          ].join(' ').toLowerCase();
          return lower.isEmpty || searchable.contains(lower);
        }).toList();
      });
    });
  }

  Future<void> _callBusiness(String? phone) async {
    final cleaned = phone?.trim() ?? '';
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openDirections(String query) async {
    if (query.trim().isEmpty) return;

    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final appState = context.watch<app.AppState>();
    final businessAppointment = appState.businessAppointment;

    if (appState.currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.businessSubPage == app.BusinessSubPage.appointment &&
        businessAppointment != null &&
        businessAppointment.type == BusinessType.petHotel) {
      return PetHotelBookingPage(
        hotel: businessAppointment,
        selectedService: appState.appointmentService,
      );
    }

    return Container(
      color: const Color(0xFFFFF6F8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search pet hotels...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                  )
                : _filteredHotels.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No pet hotels found.'
                          : 'No pet hotel results found.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: _filteredHotels.length,
                    itemBuilder: (context, index) {
                      final hotel = _filteredHotels[index];
                      return VetCard(
  data: hotel,
                        onTap: () {
                          debugPrint(
                            'OPEN PET HOTEL BUSINESS id=${hotel.id} name=${hotel.name}',
                          );
                          appState.openBusinessDetails(hotel);
                        },
                        onCallTap:
                            hotel.phone == null || hotel.phone!.trim().isEmpty
                            ? null
                            : () => _callBusiness(hotel.phone),
                        onDirectionsTap:
                            [hotel.name, hotel.address]
                                .where((item) => item.trim().isNotEmpty)
                                .join(', ')
                                .trim()
                                .isEmpty
                            ? null
                            : () => _openDirections(
                                [hotel.name, hotel.address]
                                    .where((item) => item.trim().isNotEmpty)
                                    .join(', '),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

