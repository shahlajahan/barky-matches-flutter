import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetTaxiLocationPickerPage extends StatefulWidget {
  final String title;
  final PetTaxiLocationPoint? initialLocation;

  const PetTaxiLocationPickerPage({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<PetTaxiLocationPickerPage> createState() =>
      _PetTaxiLocationPickerPageState();
}

class _PetTaxiLocationPickerPageState extends State<PetTaxiLocationPickerPage> {
  static const _istanbulCenter = LatLng(41.0082, 28.9784);

  final _search = TextEditingController();
  final _service = const PetTaxiLocationSearchService();
  GoogleMapController? _mapController;
  PetTaxiLocationPoint? _selected;
  List<PetTaxiLocationPoint> _results = const [];
  bool _searching = false;
  bool _resolvingMapTap = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  @override
  void dispose() {
    _search.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _searchLocations() async {
    final query = _search.text.trim();
    if (query.length < 4) return;

    setState(() => _searching = true);
    try {
      final results = await _service.searchLocations(query);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isNotEmpty) {
        await _select(results.first, moveCamera: true);
      }
    } catch (e) {
      debugPrint('PetTaxi location search error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location search failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(
    PetTaxiLocationPoint point, {
    required bool moveCamera,
  }) async {
    setState(() => _selected = point);
    if (moveCamera) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 16),
      );
    }
  }

  Future<void> _pickFromMap(LatLng latLng) async {
    setState(() => _resolvingMapTap = true);
    try {
      final address = await _service.reverseGeocode(
        latLng.latitude,
        latLng.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selected = PetTaxiLocationPoint(
          formattedAddress: address,
          lat: latLng.latitude,
          lng: latLng.longitude,
        );
      });
    } catch (e) {
      debugPrint('PetTaxi map pick reverse geocode error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address lookup failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingMapTap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final initialTarget = selected == null
        ? _istanbulCenter
        : LatLng(selected.lat, selected.lng);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(widget.title)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: ElevatedButton.icon(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            icon: const Icon(LucideIcons.check),
            label: const Text('Use Selected Location'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _box(),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search real address',
                    hintText: 'Street, building, district',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _searchLocations,
                            icon: const Icon(LucideIcons.arrowRight),
                          ),
                  ),
                  onSubmitted: (_) => _searchLocations(),
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._results.map(
                    (point) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.mapPin),
                      title: Text(point.formattedAddress),
                      subtitle: Text(
                        '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}',
                      ),
                      onTap: () => _select(point, moveCamera: true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 330,
            clipBehavior: Clip.antiAlias,
            decoration: _box(),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: selected == null ? 11 : 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _pickFromMap,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: selected == null
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('selected_pet_taxi_location'),
                        position: LatLng(selected.lat, selected.lng),
                      ),
                    },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _box(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _resolvingMapTap ? LucideIcons.loader2 : LucideIcons.mapPin,
                  color: const Color(0xFF9E1B4F),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected == null
                        ? 'Search an address or tap the map to select an exact pickup/dropoff point.'
                        : '${selected.formattedAddress}\n${selected.lat.toStringAsFixed(6)}, ${selected.lng.toStringAsFixed(6)}',
                    style: AppTheme.body(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: AppTheme.cardShadow(opacity: 0.05),
    );
  }
}
