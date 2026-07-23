import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/business_chat_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/business/chat/business_chat_page.dart';
import 'package:barky_matches_fixed/ui/petshop/pet_shop_customer_details_page.dart';
import 'package:barky_matches_fixed/ui/petshop/pet_shop_profile_data.dart';

class PetShopListPage extends StatefulWidget {
  const PetShopListPage({super.key});

  @override
  State<PetShopListPage> createState() => _PetShopListPageState();
}

class _PetShopListPageState extends State<PetShopListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  Position? _position;
  List<BusinessCardData> _shops = const [];
  List<BusinessCardData> _filteredShops = const [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      _position ??= await _resolveLocation();
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .get();
      if (!mounted) return;

      final shops =
          snapshot.docs
              .where((doc) => PetShopProfileData.isPetShopBusiness(doc.data()))
              .map(PetShopProfileData.fromDocument)
              .map(_toBusinessCardData)
              .toList()
            ..sort((a, b) {
              final aScore = (a.rating ?? 0) * 2 - (a.distanceKm ?? 999999);
              final bScore = (b.rating ?? 0) * 2 - (b.distanceKm ?? 999999);
              return bScore.compareTo(aScore);
            });

      setState(() {
        _shops = shops;
        _filteredShops = shops;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Pet shop discovery failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  BusinessCardData _toBusinessCardData(PetShopProfileData shop) {
    double? distance;
    if (_position != null && shop.latitude != null && shop.longitude != null) {
      distance =
          Geolocator.distanceBetween(
            _position!.latitude,
            _position!.longitude,
            shop.latitude!,
            shop.longitude!,
          ) /
          1000;
    }
    return BusinessCardData(
      id: shop.id,
      name: shop.name.isEmpty
          ? AppLocalizations.of(context)!.petShopTitle
          : shop.name,
      city: shop.city,
      district: shop.district,
      address: shop.address,
      distanceKm: distance,
      specialties: shop.categories,
      services: shop.categories,
      phone: shop.phone,
      whatsapp: shop.whatsapp,
      rating: shop.rating,
      reviewsCount: shop.reviewCount,
      workingHours: shop.workingHours,
      description: shop.description,
      isPartner: true,
      isVerified: shop.isVerified,
      status: 'approved',
      type: BusinessType.petShop,
      instagram: shop.instagram,
      website: shop.website,
      logoUrl: shop.logoUrl ?? shop.coverUrl,
      rawData: {...shop.rawData, '_productOwnerId': shop.productOwnerId},
    );
  }

  Future<Position?> _resolveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
    } catch (_) {
      return null;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = value.trim().toLowerCase();
      setState(() {
        _filteredShops = query.isEmpty
            ? _shops
            : _shops.where((shop) {
                return [
                  shop.name,
                  shop.address,
                  shop.city,
                  shop.district,
                  ...shop.specialties,
                ].join(' ').toLowerCase().contains(query);
              }).toList();
      });
    });
  }

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openBusinessChat(BusinessCardData shop) async {
    final userId = context.read<AppState>().currentUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final chatId = await BusinessChatService.instance.getOrCreateBusinessChat(
        businessId: shop.id,
        businessName: shop.name,
        businessLogoUrl: shop.logoUrl,
        businessType: 'petshop',
        clientUserId: userId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessChatPage(
            chatId: chatId,
            businessName: shop.name,
            viewerRole: 'client',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Open Pet Shop chat failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.somethingWentWrong),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final selectedShop = context.select<AppState, BusinessCardData?>(
      (state) => state.selectedPetShop,
    );

    return Stack(
      children: [
        Container(
          color: const Color(0xFFFFF6F8),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFC107)),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: l10n.searchPetShopsHint,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _hasError
                          ? _MessageState(
                              text: l10n.petShopsLoadError,
                              buttonText: l10n.retryButton,
                              onPressed: _loadShops,
                            )
                          : _filteredShops.isEmpty
                          ? _MessageState(text: l10n.noPetShopsFound)
                          : RefreshIndicator(
                              onRefresh: _loadShops,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final horizontal = constraints.maxWidth >= 760
                                      ? (constraints.maxWidth - 720) / 2
                                      : 16.0;
                                  return ListView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontal,
                                      8,
                                      horizontal,
                                      90,
                                    ),
                                    itemCount: _filteredShops.length,
                                    itemBuilder: (context, index) {
                                      final shop = _filteredShops[index];
                                      return BusinessCard(
                                        data: shop,
                                        onTap: () =>
                                            appState.openBusinessDetails(shop),
                                        onMessageTap: () =>
                                            _openBusinessChat(shop),
                                        onCallTap: shop.phone == null
                                            ? null
                                            : () => _launch(
                                                Uri(
                                                  scheme: 'tel',
                                                  path: shop.phone,
                                                ),
                                              ),
                                        onWhatsAppTap: shop.whatsapp == null
                                            ? null
                                            : () => _launch(
                                                Uri.parse(
                                                  'https://wa.me/${shop.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '')}',
                                                ),
                                              ),
                                        onDirectionsTap: shop.address.isEmpty
                                            ? null
                                            : () => _launch(
                                                Uri.parse(
                                                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${shop.name}, ${shop.address}')}',
                                                ),
                                              ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
        ),
        if (selectedShop != null)
          Positioned.fill(
            child: PetShopCustomerDetailsPage(
              key: ValueKey(selectedShop.id),
              business: selectedShop,
              onClose: appState.closePetShopDetails,
            ),
          ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.text, this.buttonText, this.onPressed});

  final String text;
  final String? buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.body(color: AppTheme.muted),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(buttonText!)),
          ],
        ],
      ),
    ),
  );
}
