import 'package:flutter/material.dart';

import '../pet_taxi_location_picker_page.dart';
import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';

import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';

import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/repositories/pet_taxi_business_repository.dart';

class PetTaxiBottomSheet extends StatefulWidget {
  const PetTaxiBottomSheet({super.key});

  @override
  State<PetTaxiBottomSheet> createState() => _PetTaxiBottomSheetState();
}

class _PetTaxiBottomSheetState extends State<PetTaxiBottomSheet> {
  PetTaxiLocationPoint? _pickup;
  PetTaxiLocationPoint? _destination;
  List<Dog> _dogs = [];

  Dog? _selectedDog;

  Future<void> _pickLocation(String title, bool isPickup) async {
    final result = await Navigator.push<PetTaxiLocationPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => PetTaxiLocationPickerPage(
          title: title,
          initialLocation: isPickup ? _pickup : _destination,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      if (isPickup) {
        _pickup = result;
      } else {
        _destination = result;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  void _loadDogs() {
    final dogs = context.read<AppState>().myDogs;

    setState(() {
      _dogs = dogs;

      if (dogs.isNotEmpty) {
        _selectedDog = dogs.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .28,
      minChildSize: .20,
      maxChildSize: .85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Row(
                children: [
                  Icon(Icons.pets, size: 22, color: Color(0xff444444)),
                  SizedBox(width: 8),
                  Text(
                    "Pet Taxi",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                "Safe & trusted transportation for your pet",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  _pickLocation("Pickup Location", true);
                },
                child: _Tile(
                  icon: Icons.location_on_outlined,
                  title: "Pickup",
                  subtitle:
                      _pickup?.formattedAddress ?? "Select pickup location",
                ),
              ),

              const SizedBox(height: 14),

              GestureDetector(
                onTap: () {
                  _pickLocation("Destination", false);
                },
                child: _Tile(
                  icon: Icons.flag_outlined,
                  title: "Destination",
                  subtitle:
                      _destination?.formattedAddress ?? "Where are you going?",
                ),
              ),

              const SizedBox(height: 14),

                GestureDetector(
                  onTap: () async {
                    final dog = await showModalBottomSheet<Dog>(
                      context: context,
                      builder: (_) {
                        if (_dogs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'No pets found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add a pet to request a Pet Taxi ride.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView(
                          children: _dogs.map((dog) {
                            return ListTile(
                              leading: const Icon(Icons.pets),
                              title: Text(dog.name),
                              onTap: () {
                                Navigator.pop(context, dog);
                              },
                            );
                          }).toList(),
                        );
                      },
                    );

                  if (dog != null) {
                    setState(() {
                      _selectedDog = dog;
                    });
                  }
                },
                child: _Tile(
                  icon: Icons.pets_outlined,
                  title: "Pet",
                  subtitle: _selectedDog?.name ?? "Select your pet",
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final business = await PetTaxiBusinessRepository()
                        .findNearestBusiness(pickup: _pickup!);

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PetTaxiBookingPage(
                          business: business,
                          initialPickup: _pickup,
                          initialDropoff: _destination,
                          initialDog: _selectedDog,
                        ),
                      ),
                    );
                  },
                  child: const Text("Continue"),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF6F7F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
