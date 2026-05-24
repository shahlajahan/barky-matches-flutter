import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/add_dog_page.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class CreateMemorialPage extends StatefulWidget {
  const CreateMemorialPage({super.key});

  @override
  State<CreateMemorialPage> createState() => _CreateMemorialPageState();
}

class _CreateMemorialPageState extends State<CreateMemorialPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _storyController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  Position? _selectedPosition;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  final _picker = ImagePicker();

  Dog? _selectedPet;
  XFile? _pickedPhoto;
  String? _treeType;
  String _visibility = 'Public';
  bool _submitting = false;
  bool _loadingPets = true;
  List<Dog> _pets = [];

  static const _treeTypes = ['Olive Tree', 'Sakura', 'Oak', 'Pine'];
  static const _visibilityOptions = ['Public', 'Friends Only', 'Private'];
  static const _fallbackMemorialLocation = LatLng(41.0082, 28.9784);

 @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {

    await _loadPets();

    if (!mounted) return;

    await _initializeCurrentLocation();
  });
}

  @override
  void dispose() {
    _mapController?.dispose();
    _titleController.dispose();
    _storyController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    final appState = context.read<AppState>();

    setState(() {
      _loadingPets = true;
    });

    try {
      await appState.loadMyDogs();

      if (!mounted) return;

      setState(() {
        _pets = List<Dog>.from(appState.myDogs);
      });
    } catch (e) {
      debugPrint('❌ LOAD PETS ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPets = false;
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickMedia();

      if (file == null || !mounted) return;

      setState(() {
        _pickedPhoto = file;
      });
    } catch (e) {
      debugPrint("❌ MEMORIAL PICK ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this image. Please try another photo.'),
        ),
      );
    }
  }

  Future<bool> _ensureLocationPermission({bool showMessages = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showMessages) {
          _showMessage('Please enable location services to use your location.');
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (showMessages) {
          _showMessage(
            'Location permission is permanently denied. Enable it in settings.',
          );
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        if (showMessages) {
          _showMessage('Location permission is required to use your location.');
        }
        return false;
      }

      if (mounted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      }

      return true;
    } catch (e) {
      debugPrint('❌ LOCATION PERMISSION ERROR: $e');
      if (showMessages) {
        _showMessage('Could not check location permission.');
      }
      return false;
    }
  }

  Future<Position?> _getCurrentPosition({bool showMessages = true}) async {
    final hasPermission = await _ensureLocationPermission(
      showMessages: showMessages,
    );
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('❌ LOCATION ERROR: $e');
      if (showMessages) {
        _showMessage('Could not get current location.');
      }
      return null;
    }
  }

  Future<void> _initializeCurrentLocation() async {
    final pos = await _getCurrentPosition(showMessages: false);
    if (pos == null || !mounted) return;

    _setSelectedPosition(pos, moveCamera: true);
  }

  Future<void> _pickLocation() async {
    final pos = await _getCurrentPosition();
    if (pos == null || !mounted) return;

    _setSelectedPosition(pos, moveCamera: true);
  }

  Position _positionFromLatLng(LatLng latLng) {
    return Position(
      longitude: latLng.longitude,
      latitude: latLng.latitude,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }

  LatLng get _currentMapTarget {
    final selectedPosition = _selectedPosition;
    if (selectedPosition == null) {
      return _fallbackMemorialLocation;
    }

    return LatLng(selectedPosition.latitude, selectedPosition.longitude);
  }

  Set<Marker> get _selectedLocationMarkers {
    final selectedPosition = _selectedPosition;
    if (selectedPosition == null) return {};

    return {
      Marker(
        markerId: const MarkerId('selected_memorial_location'),
        position: LatLng(selectedPosition.latitude, selectedPosition.longitude),
      ),
    };
  }

  void _setSelectedPosition(Position position, {bool moveCamera = false}) {
    setState(() {
      _selectedPosition = position;
    });

    if (moveCamera) {
      _moveCameraToPosition(position);
    }
  }

  Future<void> _moveCameraToPosition(Position position) async {
    await _moveCameraToLatLng(LatLng(position.latitude, position.longitude));
  }

  Future<void> _moveCameraToLatLng(LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 16)),
    );
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final ownerId = appState.currentUserId;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPet == null) {
      _showMessage('Please select a pet.');
      return;
    }

    if (_treeType == null) {
      _showMessage('Please select a tree.');
      return;
    }

    if (ownerId == null || ownerId.isEmpty || appState.isGuestUser) {
      _showMessage('Please sign in to create a memorial.');
      return;
    }
    if (_selectedPosition == null) {
      _showMessage('Please select a memorial location.');
      return;
    }
    setState(() {
      _submitting = true;
    });

    try {
      final petPhoto = _selectedPet!.imagePaths.isNotEmpty
          ? _selectedPet!.imagePaths.first
          : null;

      await FirebaseFirestore.instance.collection('green_memorials').add({
        'ownerId': ownerId,
        'ownerName': appState.currentUserName,

        'petId': _selectedPet!.id,
        'petName': _selectedPet!.name,
        'petPhoto': petPhoto,

        'title': _titleController.text.trim(),
        'story': _storyController.text.trim(),

        'treeType': _treeType,
        'visibility': _visibility,

        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),

        'lat': _selectedPosition?.latitude,
        'lng': _selectedPosition?.longitude,

        'createdAt': FieldValue.serverTimestamp(),

        'likesCount': 0,
        'commentsCount': 0,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not create memorial. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddPet() async {
    final appState = context.read<AppState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddDogPage(
          onDogAdded: (dog) {
            appState.setMyDogs([dog]);
          },
          favoriteDogs: appState.favoriteDogs,
          onToggleFavorite: appState.onToggleFavorite,
        ),
      ),
    );

    await _loadPets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Create Memorial')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _Header(),
              const SizedBox(height: 18),
              _SectionTitle('Select Pet'),
              if (_loadingPets)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_pets.isEmpty)
                _NoPetsPanel(onAddPet: _openAddPet)
              else
                _PetSelector(
                  pets: _pets,
                  selectedPet: _selectedPet,
                  onSelected: (pet) {
                    setState(() {
                      _selectedPet = pet;
                    });
                  },
                ),
              const SizedBox(height: 18),
              _SectionTitle('Upload Photo'),
              _PhotoPicker(file: _pickedPhoto, onPick: _pickPhoto),
              const SizedBox(height: 18),
              _SectionTitle('Memorial Story'),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Memorial title'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please enter a memorial title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storyController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Story / message',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please write a short story.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _SectionTitle('Tree Selection'),
              _ChoiceGrid(
                values: _treeTypes,
                selected: _treeType,
                onSelected: (value) {
                  setState(() {
                    _treeType = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              _SectionTitle('Visibility'),
              _ChoiceGrid(
                values: _visibilityOptions,
                selected: _visibility,
                onSelected: (value) {
                  setState(() {
                    _visibility = value;
                  });
                },
              ),
              _SectionTitle('Memorial Location'),

              Container(
  height: 320,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(
      AppTheme.radiusCard,
    ),
    boxShadow: AppTheme.cardShadow(opacity: 0.06),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(
      AppTheme.radiusCard,
    ),
    child: Stack(
      children: [

        GoogleMap(
  onMapCreated: (controller) {
    _mapController = controller;

    final selectedPosition = _selectedPosition;

    if (selectedPosition != null) {
      _moveCameraToPosition(selectedPosition);
    }
  },

  initialCameraPosition: CameraPosition(
    target: _currentMapTarget,
    zoom: 13,
  ),

  myLocationEnabled: _locationPermissionGranted,
  myLocationButtonEnabled: true,

  zoomControlsEnabled: true,
  zoomGesturesEnabled: true,
  scrollGesturesEnabled: true,
  rotateGesturesEnabled: true,
  tiltGesturesEnabled: true,

  compassEnabled: true,

  onTap: (LatLng pos) {
    _setSelectedPosition(
      _positionFromLatLng(pos),
    );
  },

  markers: _selectedLocationMarkers,
),

        Positioned(
          right: 14,
          bottom: 14,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {

                final pos =
                    await _getCurrentPosition();

                if (pos == null) return;

                _setSelectedPosition(
                  pos,
                  moveCamera: true,
                );
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),

              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.location_on),
                label: Text(
                  _selectedPosition == null
                      ? 'Use Current Location'
                      : 'Location Added',
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Memorial'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(opacity: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Memorial', style: AppTheme.h1(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Honor your beloved pet by planting a memory through nature.',
            style: AppTheme.body(color: Colors.white.withValues(alpha: 0.86)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: AppTheme.h2()),
    );
  }
}

class _NoPetsPanel extends StatelessWidget {
  final VoidCallback onAddPet;

  const _NoPetsPanel({required this.onAddPet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const Icon(Icons.pets, color: AppTheme.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            'Add a pet before creating a memorial.',
            textAlign: TextAlign.center,
            style: AppTheme.body(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddPet,
            icon: const Icon(Icons.add),
            label: const Text('Add Pet First'),
          ),
        ],
      ),
    );
  }
}

class _PetSelector extends StatelessWidget {
  final List<Dog> pets;
  final Dog? selectedPet;
  final ValueChanged<Dog> onSelected;

  const _PetSelector({
    required this.pets,
    required this.selectedPet,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: pets.map((pet) {
        final selected = selectedPet?.id == pet.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () => onSelected(pet),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: selected
                        ? AppTheme.accent
                        : Colors.black.withValues(alpha: 0.06),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _ImageThumb(
                      path: pet.imagePaths.isNotEmpty
                          ? pet.imagePaths.first
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.h3(),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pet.breed.isEmpty ? pet.petType : pet.breed,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.caption(size: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? AppTheme.accent : AppTheme.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? file;
  final VoidCallback onPick;

  const _PhotoPicker({required this.file, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Image.file(
                File(file!.path),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: const Icon(
                Icons.add_photo_alternate,
                color: AppTheme.success,
                size: 42,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose Photo'),
          ),
          const SizedBox(height: 4),
          Text(
            'Photo upload will be connected later. Preview is local for now.',
            textAlign: TextAlign.center,
            style: AppTheme.caption(),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((value) {
        final isSelected = selected == value;

        return InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => onSelected(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.card : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: isSelected
                    ? AppTheme.card
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: AppTheme.cardShadow(opacity: 0.04),
            ),
            child: Text(
              value,
              style: AppTheme.body(
                color: isSelected ? Colors.white : AppTheme.textDark,
                weight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String? path;

  const _ImageThumb({this.path});

  @override
  Widget build(BuildContext context) {
    final value = path?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: value.isEmpty
            ? _fallback()
            : value.startsWith('http')
            ? Image.network(
                value,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
            : Image.file(
                File(value),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(Icons.pets, color: AppTheme.success),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
    boxShadow: AppTheme.cardShadow(opacity: 0.04),
  );
}
