import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_location_permission_service.dart';

class PetTaxiLocationPickerPage extends StatefulWidget {
  final String title;
  final PetTaxiLocationPoint? initialLocation;
  final Future<List<PetTaxiLocationPoint>> Function(String query)?
  locationSearch;
  final bool initializeLocation;

  const PetTaxiLocationPickerPage({
    super.key,
    required this.title,
    this.initialLocation,
    this.locationSearch,
    this.initializeLocation = true,
  });

  @override
  State<PetTaxiLocationPickerPage> createState() =>
      _PetTaxiLocationPickerPageState();
}

class _PetTaxiLocationPickerPageState extends State<PetTaxiLocationPickerPage> {
  static const _istanbulCenter = LatLng(41.0082, 28.9784);

  final _search = TextEditingController();
  final _service = const PetTaxiLocationSearchService();
  late final PetTaxiLocationSearchController _searchController =
      PetTaxiLocationSearchController(
        search: widget.locationSearch ?? _service.searchLocations,
      );
  final _permissionService = const PetTaxiLocationPermissionService();
  GoogleMapController? _mapController;
  PetTaxiLocationPoint? _selected;
  List<PetTaxiLocationPoint> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _searchError;
  bool _resolvingMapTap = false;
  bool _myLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    if (widget.initializeLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeMyLocation();
      });
    }
  }

  @override
  void dispose() {
    _searchController.cancelPending();
    _search.dispose();
    super.dispose();
  }

  Future<void> _initializeMyLocation() async {
    if (!mounted) {
      return;
    }

    final granted = await _permissionService.ensureForegroundPermission(
      context,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _myLocationEnabled = granted;
    });
  }

  Future<void> _searchLocations() async {
    await _searchController.searchNow(
      _search.text,
      onSearching: _markSearchStarted,
      onResults: _showSearchResults,
      onError: _showSearchError,
      onCleared: _clearSearchResults,
    );
  }

  void _onSearchChanged(String value) {
    if (_selected != null) {
      setState(() => _selected = null);
    }
    _searchController.schedule(
      value,
      onSearching: _markSearchStarted,
      onResults: _showSearchResults,
      onError: _showSearchError,
      onCleared: _clearSearchResults,
    );
  }

  void _markSearchStarted() {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _hasSearched = false;
      _searchError = null;
      _results = const [];
    });
  }

  void _showSearchResults(List<PetTaxiLocationPoint> results) {
    if (!mounted) return;
    setState(() {
      _searching = false;
      _hasSearched = true;
      _searchError = null;
      _results = results;
    });
  }

  void _showSearchError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _searching = false;
      _hasSearched = true;
      _results = const [];
      _searchError = l10n.locationSearchFailed(error.toString());
    });
  }

  void _clearSearchResults() {
    if (!mounted) return;
    setState(() {
      _searching = false;
      _hasSearched = false;
      _searchError = null;
      _results = const [];
    });
  }

  Future<void> _select(
    PetTaxiLocationPoint point, {
    required bool moveCamera,
  }) async {
    _searchController.cancelPending();
    _search.value = TextEditingValue(
      text: point.formattedAddress,
      selection: TextSelection.collapsed(offset: point.formattedAddress.length),
    );
    setState(() {
      _selected = point;
      _results = const [];
      _searchError = null;
      _hasSearched = false;
    });
    if (moveCamera) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 16),
      );
    }
  }

  Future<void> _pickFromMap(LatLng latLng) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _resolvingMapTap = true);
    try {
      final address = await _service.reverseGeocode(
        latLng.latitude,
        latLng.longitude,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = PetTaxiLocationPoint(
          formattedAddress: address,
          lat: latLng.latitude,
          lng: latLng.longitude,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addressLookupFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingMapTap = false);
      }
    }
  }

  Future<void> _centerOnUser() async {
    final l10n = AppLocalizations.of(context)!;
    final granted = await _permissionService.ensureForegroundPermission(
      context,
    );
    if (!mounted || !granted) {
      return;
    }

    setState(() {
      _myLocationEnabled = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.currentLocationLoadFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selected;
    final initialTarget = selected == null
        ? _istanbulCenter
        : LatLng(selected.lat, selected.lng);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 4,
        elevation: 0,
        leadingWidth: 52,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            icon: const Icon(LucideIcons.check),
            label: Text(l10n.useSelectedLocation),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _box(),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xffED1E79),
                        width: 1.5,
                      ),
                    ),
                    labelText: l10n.searchRealAddress,
                    hintText: l10n.streetBuildingDistrict,
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 26,
                      color: Colors.black87,
                    ),
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
                            icon: const Icon(LucideIcons.arrowRight, size: 28),
                          ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _searchLocations(),
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _searchError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ] else if (_hasSearched && !_searching && _results.isEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.noResults,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
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
          const SizedBox(height: 18),
          Container(
            height: 350,
            clipBehavior: Clip.antiAlias,
            decoration: _box(),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: selected == null ? 11 : 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _pickFromMap,
              myLocationEnabled: _myLocationEnabled,
              myLocationButtonEnabled: false,
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
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        ? 'Search an address or tap the map to choose an exact location.'
                        : '${selected.formattedAddress}\n${selected.lat.toStringAsFixed(6)}, ${selected.lng.toStringAsFixed(6)}',
                    style: AppTheme.body(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _centerOnUser();
            },
            icon: const Icon(LucideIcons.locateFixed),
            label: Text(l10n.useMyCurrentLocation),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
