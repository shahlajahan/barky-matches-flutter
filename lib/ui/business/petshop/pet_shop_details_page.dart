import 'package:flutter/material.dart';
import '../../../models/business_draft.dart';

class PetShopDetailsPage extends StatefulWidget {
  final BusinessDraft baseDraft;

  const PetShopDetailsPage({super.key, required this.baseDraft});

  @override
  State<PetShopDetailsPage> createState() => _PetShopDetailsPageState();
}

class _PetShopDetailsPageState extends State<PetShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // 🟣 SECTION 1
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();

  // 🟡 SECTION 2
  final List<String> _shopTypes = [
    'Pet Food',
    'Accessories',
    'Clothing',
    'Grooming',
    'Mixed',
  ];
  final List<String> _selectedShopTypes = [];

  // 🟢 SECTION 3
  final List<String> _categories = [
    'Dry Food',
    'Wet Food',
    'Treats',
    'Toys',
    'Beds',
    'Clothes',
    'Leashes',
    'Health Products',
  ];
  final List<String> _selectedCategories = [];

  // 🔵 SECTION 4
  final _brands = TextEditingController();

  // 🟠 SECTION 5
  String _priceLevel = 'mid';

  // 🟣 SECTION 6
  String _hasDelivery = 'yes';
  final String _onlineOrder = 'no';
  final String _whatsappOrder = 'yes';

  // 🟡 SECTION 7
  final _workingHours = TextEditingController();

  // 🟢 SECTION 8
  final _bio = TextEditingController();

  // 🟠 SECTION 9
  String _hasOffers = 'yes';
  final _offerDetails = TextEditingController();

  bool _loading = false;

  void _toggle(List<String> list, String value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
  }

  Map<String, dynamic> _buildData() {
    return {
      'shopName': _shopName.text.trim(),
      'ownerName': _ownerName.text.trim(),
      'shopTypes': _selectedShopTypes,
      'categories': _selectedCategories,
      'brands': _brands.text.trim(),

      'pricing': {'level': _priceLevel},

      'sales': {
        'delivery': _hasDelivery,
        'onlineOrder': _onlineOrder,
        'whatsappOrder': _whatsappOrder,
      },

      'workingHours': _workingHours.text.trim(),

      'profile': {'bio': _bio.text.trim()},

      'promotion': {
        'hasOffers': _hasOffers,
        'details': _offerDetails.text.trim(),
      },
    };
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedShopTypes.isEmpty) {
      _snack('Select at least one shop type');
      return;
    }

    if (_selectedCategories.isEmpty) {
      _snack('Select at least one category');
      return;
    }

    setState(() => _loading = true);

    try {
      final updatedDraft = widget.baseDraft.copyWith(
        sectorData: {...widget.baseDraft.sectorData, 'petshop': _buildData()},
      );

      // 🔥 فعلاً فقط برگردون
      Navigator.pop(context, updatedDraft);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _chips(List<String> items, List<String> selected) {
    return Wrap(
      spacing: 8,
      children: items.map((e) {
        return FilterChip(
          label: Text(e),
          selected: selected.contains(e),
          onSelected: (_) => _toggle(selected, e),
        );
      }).toList(),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PetShop Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_shopName, 'Shop Name'),
            _field(_ownerName, 'Owner Name'),

            const SizedBox(height: 10),
            const Text("Shop Types"),
            _chips(_shopTypes, _selectedShopTypes),

            const SizedBox(height: 20),
            const Text("Categories"),
            _chips(_categories, _selectedCategories),

            _field(_brands, 'Brands'),

            const SizedBox(height: 20),
            const Text("Price Level"),
            DropdownButtonFormField(
              initialValue: _priceLevel,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'mid', child: Text('Mid')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (v) => setState(() => _priceLevel = v as String),
            ),

            const SizedBox(height: 20),
            const Text("Delivery"),
            SwitchListTile(
              value: _hasDelivery == 'yes',
              onChanged: (v) => setState(() => _hasDelivery = v ? 'yes' : 'no'),
              title: const Text("Has Delivery"),
            ),

            _field(_workingHours, 'Working Hours'),

            _field(_bio, 'Description'),

            const SizedBox(height: 20),
            const Text("Offers"),
            SwitchListTile(
              value: _hasOffers == 'yes',
              onChanged: (v) => setState(() => _hasOffers = v ? 'yes' : 'no'),
              title: const Text("Has Offers"),
            ),

            if (_hasOffers == 'yes') _field(_offerDetails, 'Offer Details'),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
