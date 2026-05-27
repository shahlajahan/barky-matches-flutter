import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdoptionCenterDashboardInfoTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const AdoptionCenterDashboardInfoTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<AdoptionCenterDashboardInfoTab> createState() =>
      _AdoptionCenterDashboardInfoTabState();
}

class _AdoptionCenterDashboardInfoTabState
    extends State<AdoptionCenterDashboardInfoTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _addressController;
  late final TextEditingController _websiteController;
  late final TextEditingController _instagramController;

  @override
  void initState() {
    super.initState();

    final profile = Map<String, dynamic>.from(
      widget.businessData['profile'] ?? {},
    );
    final contact = Map<String, dynamic>.from(
      widget.businessData['contact'] ?? {},
    );

    _nameController = TextEditingController(text: profile['displayName'] ?? '');
    _descriptionController = TextEditingController(
      text: profile['description'] ?? '',
    );
    _phoneController = TextEditingController(text: contact['phone'] ?? '');
    _whatsappController = TextEditingController(
      text: contact['whatsapp'] ?? '',
    );
    _cityController = TextEditingController(text: contact['city'] ?? '');
    _districtController = TextEditingController(
      text: contact['district'] ?? '',
    );
    _addressController = TextEditingController(
      text: contact['addressLine'] ?? '',
    );
    _websiteController = TextEditingController(text: contact['website'] ?? '');
    _instagramController = TextEditingController(
      text: contact['instagram'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .set({
          'profile': {
            'displayName': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
          },
          'contact': {
            'phone': _phoneController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
            'website': _websiteController.text.trim(),
            'instagram': _instagramController.text.trim(),
            'city': _cityController.text.trim(),
            'district': _districtController.text.trim(),
            'addressLine': _addressController.text.trim(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adoption Center Info',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Center name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappController,
            decoration: const InputDecoration(labelText: 'WhatsApp'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteController,
            decoration: const InputDecoration(labelText: 'Website'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instagramController,
            decoration: const InputDecoration(labelText: 'Instagram'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _districtController,
            decoration: const InputDecoration(labelText: 'District'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Save Center Info'),
            ),
          ),
        ],
      ),
    );
  }
}
