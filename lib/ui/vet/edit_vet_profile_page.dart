import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class EditVetProfilePage extends StatefulWidget {
  final String businessId;

  const EditVetProfilePage({super.key, required this.businessId});

  @override
  State<EditVetProfilePage> createState() => _EditVetProfilePageState();
}

class _EditVetProfilePageState extends State<EditVetProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _clinicNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();
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
      final vetData =
          (sectorData['vet'] as Map<String, dynamic>?) ??
          (sectorData['veterinarian'] as Map<String, dynamic>?) ??
          {};
      final vetProfile = (vetData['profile'] as Map<String, dynamic>?) ?? {};

      _clinicNameController.text =
          (profile['displayName'] ??
                  profile['businessName'] ??
                  vetData['clinicName'] ??
                  vetData['vetName'] ??
                  '')
              .toString();

      _bioController.text =
          (profile['bio'] ?? profile['description'] ?? vetProfile['bio'] ?? '')
              .toString();

      _phoneController.text = (contact['phone'] ?? '').toString();
      _whatsappController.text = (contact['whatsapp'] ?? '').toString();
      _emailController.text = (contact['email'] ?? '').toString();
      _websiteController.text = (contact['website'] ?? '').toString();
      final vetProfileContent =
          (vetData['profileContent'] as Map<String, dynamic>?) ?? {};

      final socialMedia =
          (vetProfileContent['socialMedia'] as Map<String, dynamic>?) ?? {};

      _instagramController.text =
          (socialMedia['instagram'] ??
                  vetProfile['instagram'] ??
                  vetData['instagram'] ??
                  contact['instagram'] ??
                  '')
              .toString();
      _cityController.text = (contact['city'] ?? '').toString();
      _districtController.text = (contact['district'] ?? '').toString();
      _addressController.text = (contact['address'] ?? '').toString();

      _workingHoursController.text = (vetData['workingHours'] ?? '').toString();
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
              'displayName': _clinicNameController.text.trim(),
              'businessName': _clinicNameController.text.trim(),
              'bio': _bioController.text.trim(),
              'description': _bioController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'contact': {
              'phone': _phoneController.text.trim(),
              'whatsapp': _whatsappController.text.trim(),
              'email': _emailController.text.trim(),
              'website': _websiteController.text.trim(),
              'instagram': _instagramController.text.trim(),
              'city': _cityController.text.trim(),
              'district': _districtController.text.trim(),
              'address': _addressController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'sectorData': {
              'vet': {
                'clinicName': _clinicNameController.text.trim(),
                'vetName': _clinicNameController.text.trim(),
                'workingHours': _workingHoursController.text.trim(),
                'profile': {
                  'bio': _bioController.text.trim(),
                  'instagram': _instagramController.text.trim(),
                },

                'profileContent': {
                  'bio': _bioController.text.trim(),

                  'socialMedia': {
                    'instagram': _instagramController.text.trim(),
                  },
                },
                'updatedAt': FieldValue.serverTimestamp(),
              },
              'veterinarian': {
                'clinicName': _clinicNameController.text.trim(),
                'vetName': _clinicNameController.text.trim(),
                'workingHours': _workingHoursController.text.trim(),
                'profile': {
                  'bio': _bioController.text.trim(),
                  'instagram': _instagramController.text.trim(),
                },

                'profileContent': {
                  'bio': _bioController.text.trim(),

                  'socialMedia': {
                    'instagram': _instagramController.text.trim(),
                  },
                },
                'updatedAt': FieldValue.serverTimestamp(),
              },
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vet profile updated successfully')),
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
    _clinicNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Edit Vet Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _field(
                    _clinicNameController,
                    'Clinic Name',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Clinic name is required';
                      }
                      return null;
                    },
                  ),
                  _field(_bioController, 'About / Bio', maxLines: 4),
                  _field(_phoneController, 'Phone'),
                  _field(_whatsappController, 'WhatsApp'),
                  _field(_emailController, 'Email'),
                  _field(_websiteController, 'Website'),
                  _field(_instagramController, 'Instagram'),
                  _field(_cityController, 'City'),
                  _field(_districtController, 'District'),
                  _field(_addressController, 'Address'),
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
