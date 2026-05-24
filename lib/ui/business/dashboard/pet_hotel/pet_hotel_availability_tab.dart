import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetHotelAvailabilityTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const PetHotelAvailabilityTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<PetHotelAvailabilityTab> createState() =>
      _PetHotelAvailabilityTabState();
}

class _PetHotelAvailabilityTabState extends State<PetHotelAvailabilityTab> {
  final TextEditingController _capacityController = TextEditingController();
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _hotelData(Map<String, dynamic> data) {
    final sectorData = Map<String, dynamic>.from(data['sectorData'] ?? {});
    return Map<String, dynamic>.from(
      sectorData['pet_hotel'] ??
          sectorData['hotel'] ??
          sectorData['petHotel'] ??
          {},
    );
  }

  int _maxCapacity(Map<String, dynamic> data) {
    final hotel = _hotelData(data);
    final capacity = Map<String, dynamic>.from(hotel['capacity'] ?? {});
    final raw =
        capacity['maxCapacity'] ?? hotel['maxCapacity'] ?? data['maxCapacity'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  void _seedCapacityField(Map<String, dynamic> data) {
    if (_seeded) return;
    _seeded = true;
    final maxCapacity = _maxCapacity(data);
    _capacityController.text = maxCapacity > 0 ? '$maxCapacity' : '25';
  }

  Future<void> _saveCapacity() async {
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    if (capacity <= 0 || _saving) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set({
            'sectorData': {
              'pet_hotel': {
                'capacity': {'maxCapacity': capacity},
                'maxCapacity': capacity,
              },
              'hotel': {
                'capacity': {'maxCapacity': capacity},
                'maxCapacity': capacity,
              },
            },
            'maxCapacity': capacity,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Availability updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.businessData;
    final maxCapacity = _maxCapacity(data);
    _seedCapacityField(data);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Availability', style: AppTheme.h2()),
        const SizedBox(height: 8),
        Text(
          'Capacity is used by the booking functions to prevent overlapping stays beyond available rooms.',
          style: AppTheme.caption(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
            boxShadow: AppTheme.cardShadow(opacity: 0.04),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.hotel, color: Color(0xFF9E1B4F)),
                  const SizedBox(width: 10),
                  Text(
                    'Room Capacity',
                    style: AppTheme.bodyMedium().copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum pets / rooms',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Current capacity: $maxCapacity',
                style: AppTheme.caption(color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveCapacity,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Availability'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
