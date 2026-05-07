import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business.dart';
import '../models/business_draft.dart';

class BusinessMapper {
  static Business fromDraft({
    required BusinessDraft draft,
    required String ownerUid,
  }) {
    return Business(
      id: '', // Firestore خودش میده
      type: "veterinary",

      ownerUid: ownerUid,
      ownerName: draft.profile.displayName,
      ownerRole: "veterinarian",

      name: draft.profile.displayName,
      description: draft.profile.description,
      yearEstablished: null,

      phone: draft.contact.phone,
      landline: null,
      email: draft.contact.email,

      address: draft.contact.addressLine,
      city: draft.contact.city,
      district: draft.contact.district,

      location: const GeoPoint(0, 0), // بعداً از map بگیر

      website: draft.contact.website,
      instagram: draft.contact.instagram,
      whatsapp: draft.contact.whatsapp,

      license: License(
        number: draft.legal.taxNumber,
        authority: "unknown",
        expiryDate: null,
        documentUrl: null,
      ),

      services: [], // بعداً پر میشه

      workingHours: {},

      emergency: Emergency(
        available: false,
        type: "none",
      ),

      animalTypes: ["dog", "cat"],

      features: Features(
        homeService: false,
        onlineConsultation: false,
        parking: false,
      ),

      logoUrl: draft.profile.logoUrl,
      images: [],

      rating: 0,
      reviewCount: 0,

      partnership: Partnership(
        model: "subscription",
        status: "pending", // 🔥 مهم
        featured: false,
      ),

      payment: Payment(
        iban: "",
        accountHolder: draft.profile.displayName,
        billingInfo: draft.legal.mersisNumber,
      ),

      marketing: Marketing(
        offersEnabled: false,
        hasDiscount: false,
        featuredScore: 0,
      ),

      isVerified: false,
      isActive: true,

      moderation: Moderation(
        status: "active",
        reportCount: 0,
      ),

      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }
}