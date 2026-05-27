import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class EditPetShopProfilePage extends StatefulWidget {
  final String businessId;

  const EditPetShopProfilePage({super.key, required this.businessId});

  @override
  State<EditPetShopProfilePage> createState() => _EditPetShopProfilePageState();
}

class _EditPetShopProfilePageState extends State<EditPetShopProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _workingHoursController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      final data = doc.data() ?? {};

      final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
      final contact = (data['contact'] as Map<String, dynamic>?) ?? {};
      final sectorData = (data['sectorData'] as Map<String, dynamic>?) ?? {};
      final petshopData =
          (sectorData['petshop'] as Map<String, dynamic>?) ?? {};
      final petshopProfile =
          (petshopData['profile'] as Map<String, dynamic>?) ?? {};

      _shopNameController.text =
          (profile['displayName'] ??
                  profile['businessName'] ??
                  petshopData['shopName'] ??
                  '')
              .toString();

      _bioController.text =
          (profile['bio'] ??
                  profile['description'] ??
                  petshopProfile['bio'] ??
                  '')
              .toString();

      _phoneController.text = (contact['phone'] ?? '').toString();
      _whatsappController.text = (contact['whatsapp'] ?? '').toString();
      _emailController.text = (contact['email'] ?? '').toString();
      _websiteController.text = (contact['website'] ?? '').toString();
      _cityController.text = (contact['city'] ?? '').toString();
      _districtController.text = (contact['district'] ?? '').toString();
      _workingHoursController.text = (petshopData['workingHours'] ?? '')
          .toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load error: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set({
            'profile': {
              'displayName': _shopNameController.text.trim(),
              'businessName': _shopNameController.text.trim(),
              'bio': _bioController.text.trim(),
              'description': _bioController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'contact': {
              'phone': _phoneController.text.trim(),
              'whatsapp': _whatsappController.text.trim(),
              'email': _emailController.text.trim(),
              'website': _websiteController.text.trim(),
              'city': _cityController.text.trim(),
              'district': _districtController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'sectorData': {
              'petshop': {
                'shopName': _shopNameController.text.trim(),
                'workingHours': _workingHoursController.text.trim(),
                'profile': {'bio': _bioController.text.trim()},
                'updatedAt': FieldValue.serverTimestamp(),
              },
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Edit PetShop Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _field(
                    _shopNameController,
                    'Shop Name',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Shop name is required';
                      }
                      return null;
                    },
                  ),
                  _field(_bioController, 'About / Bio', maxLines: 4),
                  _field(_phoneController, 'Phone'),
                  _field(_whatsappController, 'WhatsApp'),
                  _field(_emailController, 'Email'),
                  _field(_websiteController, 'Website'),
                  _field(_cityController, 'City'),
                  _field(_districtController, 'District'),
                  _field(_workingHoursController, 'Working Hours'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
