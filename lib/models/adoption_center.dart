import 'package:cloud_firestore/cloud_firestore.dart';

class AdoptionCenter {
  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? district;
  final String? instagram;
  final String? website;
  final String? phone;
  final String? whatsapp;
  final bool isFeatured;
  final String centerType; // ngo | instagram
  final String? focusType;

  AdoptionCenter({
    required this.id,
    required this.name,
    this.description,
    this.city,
    this.district,
    this.instagram,
    this.website,
    this.phone,
    this.whatsapp,
    required this.isFeatured,
    required this.centerType,
    this.focusType,
  });

  factory AdoptionCenter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AdoptionCenter(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      city: data['city'],
      district: data['district'],
      instagram: data['instagram'],
      website: data['website'],
      phone: data['phone'],
      whatsapp: data['whatsapp'],
      isFeatured: data['isFeatured'] ?? false,
      centerType: data['centerType'] ?? 'ngo',
      focusType: data['focusType'],
    );
  }
}