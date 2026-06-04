import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'adoption_pet_model.dart';

class AddEditAdoptionPetPage extends StatefulWidget {
  final String businessId;

  final AdoptionPetModel? pet;

  const AddEditAdoptionPetPage({super.key, required this.businessId, this.pet});

  @override
  State<AddEditAdoptionPetPage> createState() => _AddEditAdoptionPetPageState();
}

class _AddEditAdoptionPetPageState extends State<AddEditAdoptionPetPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;

  late final TextEditingController _breed;

  late final TextEditingController _description;

  late final TextEditingController _ageMonths;

  String _species = 'Dog';

  String _gender = 'Male';

  String _status = AdoptionPetStatus.available;

  bool _visible = true;

  bool _saving = false;

  String? _coverImageUrl;

  final List<String> _gallery = [];

  bool get isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();

    final pet = widget.pet;

    _name = TextEditingController(text: pet?.name ?? '');

    _breed = TextEditingController(text: pet?.breed ?? '');

    _description = TextEditingController(text: pet?.description ?? '');

    _ageMonths = TextEditingController(
      text: (pet?.ageMonths ?? 0) == 0 ? '' : (pet!.ageMonths).toString(),
    );

    if (pet != null) {
      _species = pet.species;
      _gender = pet.gender;
      _status = pet.status;
      _visible = pet.isVisible;

      _coverImageUrl = pet.coverImageUrl;

      _gallery.addAll(pet.gallery);
    }
  }

  @override
  void dispose() {
    _name.dispose();

    _breed.dispose();

    _description.dispose();

    _ageMonths.dispose();

    super.dispose();
  }

  Future<String> _uploadImage(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance.ref().child(
      'business_sector_docs/'
      '${widget.businessId}/'
      'adoption_center/'
      'pets/'
      '$fileName',
    );

    await ref.putFile(file);

    return ref.getDownloadURL();
  }

  Future<void> _pickCover() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) return;

      final url = await _uploadImage(File(picked.path));

      if (!mounted) return;

      setState(() {
        _coverImageUrl = url;

        if (!_gallery.contains(url)) {
          _gallery.insert(0, url);
        }
      });
    } catch (e) {
      debugPrint('PET COVER ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _pickGallery() async {
    try {
      final picker = ImagePicker();

      final images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      for (final image in images) {
        final url = await _uploadImage(File(image.path));

        _gallery.add(url);
      }

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      debugPrint('PET GALLERY ERROR: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_coverImageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add cover image')));

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final model = AdoptionPetModel(
        id: widget.pet?.id ?? '',

        businessId: widget.businessId,

        name: _name.text.trim(),

        species: _species,

        breed: _breed.text.trim(),

        ageMonths: int.tryParse(_ageMonths.text) ?? 0,

        gender: _gender,

        description: _description.text.trim(),

        status: _status,

        coverImageUrl: _coverImageUrl,

        gallery: _gallery,

        isVisible: _visible,

        createdAt: widget.pet?.createdAt,

        updatedAt: DateTime.now(),

        adoptedAt: _status == AdoptionPetStatus.adopted ? DateTime.now() : null,
      );

      final collection = FirebaseFirestore.instance.collection('adoption_pets');

      if (isEditing) {
        await collection
            .doc(widget.pet!.id)
            .set(model.toFirestore(), SetOptions(merge: true));
      } else {
        await collection.add(model.toFirestore());
      }

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint('SAVE PET ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
    });
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Pet' : 'Add Pet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton(
              onPressed: _pickCover,
              child: Text(
                _coverImageUrl == null ? 'Upload Cover' : 'Change Cover',
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _pickGallery,
              child: const Text('Add Gallery Images'),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Pet Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(
                labelText: 'Breed',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _ageMonths,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age (months)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            _dropdown<String>(
              value: _species,
              items: const ['Dog', 'Cat', 'Bird', 'Rabbit', 'Other'],
              onChanged: (v) {
                if (v == null) return;

                setState(() {
                  _species = v;
                });
              },
            ),

            const SizedBox(height: 16),

            _dropdown<String>(
              value: _gender,
              items: const ['Male', 'Female', 'Unknown'],
              onChanged: (v) {
                if (v == null) return;

                setState(() {
                  _gender = v;
                });
              },
            ),

            const SizedBox(height: 16),

            _dropdown<String>(
              value: _status,
              items: AdoptionPetStatus.values,
              onChanged: (v) {
                if (v == null) return;

                setState(() {
                  _status = v;
                });
              },
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              value: _visible,
              title: const Text('Visible'),
              onChanged: (v) {
                setState(() {
                  _visible = v;
                });
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Create Pet'),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
