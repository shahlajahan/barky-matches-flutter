import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart' as app;
import 'l10n/app_localizations.dart';
import 'ui/business/business_card_data.dart';
import 'ui/business/groomy/groomy_appointment_page.dart';
import 'ui/business/business_card.dart';

class GroomyPage extends StatefulWidget {
  const GroomyPage({super.key});

  @override
  State<GroomyPage> createState() => _GroomyPageState();
}

class _GroomyPageState extends State<GroomyPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<BusinessCardData> _groomers = [];
  List<BusinessCardData> _filteredGroomers = [];

  @override
  void initState() {
    super.initState();
    _loadGroomersFromFirestore();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGroomersFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .get();

      if (!mounted) return;

      final groomers = snapshot.docs
          .map((doc) => _mapGroomingBusiness(doc.id, doc.data()))
          .whereType<BusinessCardData>()
          .toList();

      groomers.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _groomers = groomers;
        _filteredGroomers = groomers;
        _loading = false;
      });

      debugPrint('GROOMY PAGE LOADED businesses=${groomers.length}');
    } catch (e) {
      debugPrint('GROOMY PAGE LOAD ERROR $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  BusinessCardData? _mapGroomingBusiness(String id, Map<String, dynamic> data) {
    final root = <String, dynamic>{...data, 'id': id};
    if (!_isGroomingBusiness(root)) return null;

    final profile = _map(root['profile']);
    final contact = _map(root['contact']);
    final sectorData = _map(root['sectorData']);
    final grooming = _map(
      sectorData['grooming'] ?? sectorData['groomer'] ?? sectorData['groomy'],
    );
    final profileContent = _map(
      grooming['profileContent'] ?? grooming['content'],
    );
    final socialMedia = _map(profileContent['socialMedia']);
    final services = _map(grooming['services']);
    final workingHours = _map(grooming['workingHours']);

    final name = _firstText([
      profile['displayName'],
      profile['businessName'],
      root['displayName'],
      root['businessName'],
      root['name'],
    ]);

    final description = _firstText([
      profileContent['bio'],
      profileContent['description'],
      profile['description'],
      profile['bio'],
      root['description'],
      root['bio'],
    ]);

    final city = contact['city']?.toString().trim() ?? '';
    final district = contact['district']?.toString().trim() ?? '';
    final address = _firstText([
      contact['address'],
      [district, city].where((item) => item.isNotEmpty).join(', '),
    ]);

    final specialties = _specialties([
      profileContent['specialties'],
      profile['categories'],
      root['categories'],
      root['category'],
    ]);

    final serviceTitles = _serviceTitles([
      services['offeredServices'],
      services['services'],
      grooming['offeredServices'],
      profile['tags'],
      root['tags'],
    ]);

    final rawWorkingHours = workingHours['workingHours'];
    final workingHoursMap = <String, String>{};
    if (rawWorkingHours is Map) {
      rawWorkingHours.forEach((key, value) {
        workingHoursMap[key.toString()] = value.toString();
      });
    } else if (rawWorkingHours is String && rawWorkingHours.trim().isNotEmpty) {
      workingHoursMap['hours'] = rawWorkingHours.trim();
    }

    final ratingRaw = profile['rating'] ?? root['rating'];
    final reviewCountRaw =
        profile['reviewCount'] ??
        profile['reviewsCount'] ??
        root['reviewsCount'];

    return BusinessCardData(
      id: id,
      name: name.isNotEmpty ? name : 'Groomy',
      city: city,
      district: district,
      address: address,
      specialties: specialties.isNotEmpty ? specialties : const ['Grooming'],
      services: serviceTitles,
      phone: contact['phone']?.toString(),
      whatsapp: contact['whatsapp']?.toString() ?? contact['phone']?.toString(),
      rating: ratingRaw is num ? ratingRaw.toDouble() : null,
      isPartner:
          root['status'] == 'approved' ||
          root['isPartner'] == true ||
          grooming['featuredGroomer'] == true,
      reviewsCount: reviewCountRaw is num ? reviewCountRaw.toInt() : null,
      workingHours: workingHoursMap,
      description: description,
      isVerified: _map(root['verification'])['isVerified'] == true,
      status: root['status']?.toString() ?? 'approved',
      type: BusinessType.groomer,
      instagram:
          contact['instagram']?.toString() ??
          socialMedia['instagram']?.toString(),
      website:
          contact['website']?.toString() ?? socialMedia['website']?.toString(),
      logoUrl: _firstText([
        root['coverImageUrl'], // ADD THIS FIRST
        profile['coverUrl'], // ADD THIS TOO
        profile['logoUrl'],
        profile['logo'],
        profileContent['clinicLogoUrl'],
        profileContent['logoUrl'],
        root['logoUrl'],
      ]),
      rawData: root,
      data: root,
    );
  }

  bool _isGroomingBusiness(Map<String, dynamic> data) {
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

    return raw.contains('groom') || raw.contains('kuaf');
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

  List<String> _specialties(List<dynamic> values) {
    for (final value in values) {
      final items = _stringList(value);
      if (items.isNotEmpty) return items;
    }
    return const <String>[];
  }

  List<String> _serviceTitles(List<dynamic> values) {
    for (final value in values) {
      final items = _stringList(value);
      if (items.isNotEmpty) return items;
    }
    return const <String>['Full Grooming', 'Bath & Dry', 'Nail Trimming'];
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final lower = query.toLowerCase().trim();

      setState(() {
        _searchQuery = lower;
        _filteredGroomers = _groomers.where((business) {
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
    debugPrint('GROOMY PAGE BUILD');

    final appState = context.watch<app.AppState>();
    final businessAppointment = appState.businessAppointment;

    if (appState.currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.businessSubPage == app.BusinessSubPage.appointment &&
        businessAppointment != null &&
        businessAppointment.type == BusinessType.groomer) {
      return GroomyAppointmentPage(
        groomy: businessAppointment,
        selectedService: appState.appointmentService,
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: const Color(0xFFFFF6F8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search ${l10n.groomyTitle.toLowerCase()}...',
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
                : _filteredGroomers.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No grooming businesses found.'
                          : 'No grooming results found.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: _filteredGroomers.length,
                    itemBuilder: (context, index) {
                      final groomy = _filteredGroomers[index];
                      final addressQuery = [
                        groomy.name,
                        groomy.address,
                      ].where((item) => item.trim().isNotEmpty).join(', ');

                      return BusinessCard(
                        data: groomy,
                        onTap: () {
                          debugPrint(
                            'OPEN GROOMY BUSINESS id=${groomy.id} name=${groomy.name}',
                          );
                          appState.openBusinessDetails(groomy);
                        },
                        onCallTap:
                            groomy.phone == null || groomy.phone!.trim().isEmpty
                            ? null
                            : () => _callBusiness(groomy.phone),
                        onDirectionsTap: addressQuery.trim().isEmpty
                            ? null
                            : () => _openDirections(addressQuery),
                        onWhatsAppTap: null,
                        onMessageTap: null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
