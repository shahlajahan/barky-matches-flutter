import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sections/adoption_pet_model.dart';
import 'sections/adoption_pet_card.dart';
import 'sections/add_edit_adoption_pet_page.dart';

class AdoptionPetsTab extends StatefulWidget {
  final String businessId;

  const AdoptionPetsTab({
    super.key,
    required this.businessId,
  });

  @override
  State<AdoptionPetsTab> createState() => _AdoptionPetsTabState();
}

class _AdoptionPetsTabState extends State<AdoptionPetsTab> {
  String _statusFilter = 'all';
  String _search = '';

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('adoption_pets');

  Stream<QuerySnapshot<Map<String, dynamic>>> _petsStream() {
    return _collection
        .where('businessId', isEqualTo: widget.businessId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  List<AdoptionPetModel> _applyFilters(List<AdoptionPetModel> pets) {
    return pets.where((pet) {
      final matchesStatus = _statusFilter == 'all' || pet.status == _statusFilter;

      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return matchesStatus;

      final searchable = [
        pet.name,
        pet.species,
        pet.breed,
        pet.gender,
        pet.status,
      ].join(' ').toLowerCase();

      return matchesStatus && searchable.contains(q);
    }).toList();
  }

  Future<void> _openAddPet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditAdoptionPetPage(
          businessId: widget.businessId,
        ),
      ),
    );
  }

  Future<void> _openEditPet(AdoptionPetModel pet) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditAdoptionPetPage(
          businessId: widget.businessId,
          pet: pet,
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    AdoptionPetModel pet,
    String nextStatus,
  ) async {
    try {
      final update = <String, dynamic>{
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nextStatus == AdoptionPetStatus.adopted) {
        update['adoptedAt'] = FieldValue.serverTimestamp();
      } else {
        update['adoptedAt'] = null;
      }

      await _collection.doc(pet.id).set(update, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pet.name} status updated')),
      );
    } catch (e) {
      debugPrint('ADOPTION PET STATUS ERROR: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  Future<void> _deletePet(AdoptionPetModel pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete pet?'),
          content: Text(
            'Are you sure you want to delete ${pet.name}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _collection.doc(pet.id).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pet.name} deleted')),
      );
    } catch (e) {
      debugPrint('ADOPTION PET DELETE ERROR: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() => _search = value);
            },
            decoration: InputDecoration(
              hintText: 'Search pets',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChipButton(
                  label: 'All',
                  selected: _statusFilter == 'all',
                  onTap: () => setState(() => _statusFilter = 'all'),
                ),
                _FilterChipButton(
                  label: 'Available',
                  selected: _statusFilter == AdoptionPetStatus.available,
                  onTap: () => setState(
                    () => _statusFilter = AdoptionPetStatus.available,
                  ),
                ),
                _FilterChipButton(
                  label: 'Reserved',
                  selected: _statusFilter == AdoptionPetStatus.reserved,
                  onTap: () => setState(
                    () => _statusFilter = AdoptionPetStatus.reserved,
                  ),
                ),
                _FilterChipButton(
                  label: 'Adopted',
                  selected: _statusFilter == AdoptionPetStatus.adopted,
                  onTap: () => setState(
                    () => _statusFilter = AdoptionPetStatus.adopted,
                  ),
                ),
                _FilterChipButton(
                  label: 'Paused',
                  selected: _statusFilter == AdoptionPetStatus.paused,
                  onTap: () => setState(
                    () => _statusFilter = AdoptionPetStatus.paused,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pets_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'No adoptable pets yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add pets that are available for adoption and manage their status here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openAddPet,
              icon: const Icon(Icons.add),
              label: const Text('Add Pet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load pets:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _petsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildError(snapshot.error!);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            final pets = docs
                .map((doc) => AdoptionPetModel.fromFirestore(doc))
                .toList();

            final filteredPets = _applyFilters(pets);

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: filteredPets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                          itemCount: filteredPets.length,
                          itemBuilder: (context, index) {
                            final pet = filteredPets[index];

                            return AdoptionPetCard(
                              pet: pet,
                              onEdit: () => _openEditPet(pet),
                              onDelete: () => _deletePet(pet),
                              onStatusChanged: (nextStatus) {
                                _changeStatus(pet, nextStatus);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),

        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add_adoption_pet_${widget.businessId}',
            onPressed: _openAddPet,
            icon: const Icon(Icons.add),
            label: const Text('Add Pet'),
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF9E1B4F),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF9E1B4F),
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected ? const Color(0xFF9E1B4F) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}