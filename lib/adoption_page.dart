import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'app_state.dart';

class AdoptionPage extends StatefulWidget {
  final List<Dog> dogs;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const AdoptionPage({
    super.key,
    required this.dogs,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _AdoptionPageState createState() => _AdoptionPageState();
}

class _AdoptionPageState extends State<AdoptionPage> {
  late List<Dog> _adoptableDogs;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _applyFilters();
    _loadCurrentUserId();
  }

  void _loadCurrentUserId() {
    try {
      final userBox = Hive.box<String>('currentUserBox');
      setState(() {
        _currentUserId = userBox.get('currentUserId') ?? FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
        print('AdoptionPage - Current userId: $_currentUserId');
      });
    } catch (e) {
      print('AdoptionPage - Error loading userBox: $e');
      setState(() {
        _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user';
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _adoptableDogs = widget.dogs.where((dog) => dog.isAvailableForAdoption).toList();
      print('AdoptionPage - Filtered adoptable dogs count: ${_adoptableDogs.length}');
      for (var dog in _adoptableDogs) {
        print('AdoptionPage - Adoptable dog: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
      }
    });
  }

  void _updateDogInHive(Dog updatedDog, int originalIndex) async {
    final box = Hive.box<Dog>('dogsBox');
    if (originalIndex >= 0 && originalIndex < box.length) {
      await box.put(updatedDog.id, updatedDog);
      await FirebaseFirestore.instance.collection('dogs').doc(updatedDog.id).set({
        'id': updatedDog.id,
        'name': updatedDog.name,
        'breed': updatedDog.breed,
        'age': updatedDog.age,
        'gender': updatedDog.gender,
        'healthStatus': updatedDog.healthStatus,
        'isNeutered': updatedDog.isNeutered,
        'description': updatedDog.description,
        'traits': updatedDog.traits,
        'ownerGender': updatedDog.ownerGender,
        'imagePaths': updatedDog.imagePaths,
        'isAvailableForAdoption': updatedDog.isAvailableForAdoption,
        'isOwner': updatedDog.isOwner,
        'ownerId': updatedDog.ownerId,
        'latitude': updatedDog.latitude,
        'longitude': updatedDog.longitude,
      }, SetOptions(merge: true));
      _applyFilters();
      print('AdoptionPage - Updated dog in Hive and Firestore: ${updatedDog.name}, ID: ${updatedDog.id} at index $originalIndex');
    } else {
      print('AdoptionPage - Invalid index for updating dog: ${updatedDog.name}, ID: ${updatedDog.id}, index: $originalIndex');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              localizations.adoptionCenter ?? 'Adoption Center',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.pink[400],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _adoptableDogs.isEmpty
                ? Center(
                    child: Text(
                      localizations.noDogsAvailableForAdoption ?? 'No dogs available for adoption',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('adoption_dog_list'),
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _adoptableDogs.length,
                    itemBuilder: (context, index) {
                      final dog = _adoptableDogs[index];
                      print(
                          'AdoptionPage - Displaying dog at index $index: Name=${dog.name}, ID=${dog.id}, Breed=${dog.breed}, OwnerId=${dog.ownerId}');
                      return DogCard(
                        key: ValueKey(dog.id),
                        dog: dog,
                        allDogs: widget.dogs,
                        currentUserId: _currentUserId ?? 'default_user',
                        favoriteDogs: widget.favoriteDogs,
                        onToggleFavorite: widget.onToggleFavorite,
                        onDogUpdated: (updatedDog) {
                          final originalIndex = widget.dogs.indexOf(dog);
                          if (originalIndex != -1) {
                            _updateDogInHive(updatedDog, originalIndex);
                          }
                        },
                        selectedRequesterDogId: Provider.of<AppState>(context, listen: false).selectedRequesterDogId,
                        onRequesterDogChanged: (value) {
                          Provider.of<AppState>(context, listen: false).setSelectedRequesterDogId(value);
                        },
                        onAdopt: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Adoption request sent for ${dog.name}!'),
                            ),
                          );
                        },
                        likers: appState.dogLikes[dog.id] ?? [],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}