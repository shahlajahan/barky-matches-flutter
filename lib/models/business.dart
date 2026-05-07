import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String type;

  final String ownerUid;
  final String ownerName;
  final String ownerRole;

  final String name;
  final String description;
  final int? yearEstablished;

  final String phone;
  final String? landline;
  final String email;

  final String address;
  final String city;
  final String district;

  final GeoPoint location;

  final String? website;
  final String? instagram;
  final String? whatsapp;

  final License license;

  final List<Service> services;

  final Map<String, dynamic> workingHours;

  final Emergency emergency;

  final List<String> animalTypes;

  final Features features;

  final String? logoUrl;
  final List<String> images;

  final double rating;
  final int reviewCount;

  final Partnership partnership;

  final Payment payment;

  final Marketing marketing;

  final bool isVerified;
  final bool isActive;

  final Moderation moderation;

  final Timestamp createdAt;
  final Timestamp updatedAt;

  Business({
    required this.id,
    required this.type,
    required this.ownerUid,
    required this.ownerName,
    required this.ownerRole,
    required this.name,
    required this.description,
    this.yearEstablished,
    required this.phone,
    this.landline,
    required this.email,
    required this.address,
    required this.city,
    required this.district,
    required this.location,
    this.website,
    this.instagram,
    this.whatsapp,
    required this.license,
    required this.services,
    required this.workingHours,
    required this.emergency,
    required this.animalTypes,
    required this.features,
    this.logoUrl,
    required this.images,
    required this.rating,
    required this.reviewCount,
    required this.partnership,
    required this.payment,
    required this.marketing,
    required this.isVerified,
    required this.isActive,
    required this.moderation,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 🔥 FROM FIRESTORE
  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Business(
      id: doc.id,
      type: data['type'] ?? 'veterinary',

      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerRole: data['ownerRole'] ?? '',

      name: data['name'] ?? '',
      description: data['description'] ?? '',
      yearEstablished: data['yearEstablished'],

      phone: data['phone'] ?? '',
      landline: data['landline'],
      email: data['email'] ?? '',

      address: data['address'] ?? '',
      city: data['city'] ?? '',
      district: data['district'] ?? '',

      location: data['location'] ?? const GeoPoint(0, 0),

      website: data['website'],
      instagram: data['instagram'],
      whatsapp: data['whatsapp'],

      license: License.fromMap(data['license'] ?? {}),

      services: (data['services'] as List? ?? [])
          .map((e) => Service.fromMap(e))
          .toList(),

      workingHours: data['workingHours'] ?? {},

      emergency: Emergency.fromMap(data['emergency'] ?? {}),

      animalTypes: List<String>.from(data['animalTypes'] ?? []),

      features: Features.fromMap(data['features'] ?? {}),

      logoUrl: data['logoUrl'],
      images: List<String>.from(data['images'] ?? []),

      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,

      partnership: Partnership.fromMap(data['partnership'] ?? {}),

      payment: Payment.fromMap(data['payment'] ?? {}),

      marketing: Marketing.fromMap(data['marketing'] ?? {}),

      isVerified: data['isVerified'] ?? false,
      isActive: data['isActive'] ?? true,

      moderation: Moderation.fromMap(data['moderation'] ?? {}),

      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  /// 🔥 TO FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      "type": type,
      "ownerUid": ownerUid,
      "ownerName": ownerName,
      "ownerRole": ownerRole,
      "name": name,
      "description": description,
      "yearEstablished": yearEstablished,
      "phone": phone,
      "landline": landline,
      "email": email,
      "address": address,
      "city": city,
      "district": district,
      "location": location,
      "website": website,
      "instagram": instagram,
      "whatsapp": whatsapp,
      "license": license.toMap(),
      "services": services.map((e) => e.toMap()).toList(),
      "workingHours": workingHours,
      "emergency": emergency.toMap(),
      "animalTypes": animalTypes,
      "features": features.toMap(),
      "logoUrl": logoUrl,
      "images": images,
      "rating": rating,
      "reviewCount": reviewCount,
      "partnership": partnership.toMap(),
      "payment": payment.toMap(),
      "marketing": marketing.toMap(),
      "isVerified": isVerified,
      "isActive": isActive,
      "moderation": moderation.toMap(),
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }
}

class License {
  final String number;
  final String authority;
  final Timestamp? expiryDate;
  final String? documentUrl;

  License({
    required this.number,
    required this.authority,
    this.expiryDate,
    this.documentUrl,
  });

  factory License.fromMap(Map<String, dynamic> map) {
    return License(
      number: map['number'] ?? '',
      authority: map['authority'] ?? '',
      expiryDate: map['expiryDate'],
      documentUrl: map['documentUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "number": number,
      "authority": authority,
      "expiryDate": expiryDate,
      "documentUrl": documentUrl,
    };
  }
}

class Service {
  final String id;
  final String name;
  final int? priceFrom;
  final String description;
  final bool requiresAppointment;

  Service({
    required this.id,
    required this.name,
    this.priceFrom,
    required this.description,
    required this.requiresAppointment,
  });

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      priceFrom: map['priceFrom'],
      description: map['description'] ?? '',
      requiresAppointment: map['requiresAppointment'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "priceFrom": priceFrom,
      "description": description,
      "requiresAppointment": requiresAppointment,
    };
  }
}

class Emergency {
  final bool available;
  final String type;

  Emergency({
    required this.available,
    required this.type,
  });

  factory Emergency.fromMap(Map<String, dynamic> map) {
    return Emergency(
      available: map['available'] ?? false,
      type: map['type'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "available": available,
      "type": type,
    };
  }
}

class Features {
  final bool homeService;
  final bool onlineConsultation;
  final bool parking;

  Features({
    required this.homeService,
    required this.onlineConsultation,
    required this.parking,
  });

  factory Features.fromMap(Map<String, dynamic> map) {
    return Features(
      homeService: map['homeService'] ?? false,
      onlineConsultation: map['onlineConsultation'] ?? false,
      parking: map['parking'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "homeService": homeService,
      "onlineConsultation": onlineConsultation,
      "parking": parking,
    };
  }
}

class Partnership {
  final String model;
  final String status;
  final bool featured;

  Partnership({
    required this.model,
    required this.status,
    required this.featured,
  });

  factory Partnership.fromMap(Map<String, dynamic> map) {
    return Partnership(
      model: map['model'] ?? 'subscription',
      status: map['status'] ?? 'pending',
      featured: map['featured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "model": model,
      "status": status,
      "featured": featured,
    };
  }
}

class Payment {
  final String iban;
  final String accountHolder;
  final String billingInfo;

  Payment({
    required this.iban,
    required this.accountHolder,
    required this.billingInfo,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      iban: map['iban'] ?? '',
      accountHolder: map['accountHolder'] ?? '',
      billingInfo: map['billingInfo'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "iban": iban,
      "accountHolder": accountHolder,
      "billingInfo": billingInfo,
    };
  }
}

class Marketing {
  final bool offersEnabled;
  final bool hasDiscount;
  final int featuredScore;

  Marketing({
    required this.offersEnabled,
    required this.hasDiscount,
    required this.featuredScore,
  });

  factory Marketing.fromMap(Map<String, dynamic> map) {
    return Marketing(
      offersEnabled: map['offersEnabled'] ?? false,
      hasDiscount: map['hasDiscount'] ?? false,
      featuredScore: map['featuredScore'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "offersEnabled": offersEnabled,
      "hasDiscount": hasDiscount,
      "featuredScore": featuredScore,
    };
  }
}

class Moderation {
  final String status;
  final int reportCount;

  Moderation({
    required this.status,
    required this.reportCount,
  });

  factory Moderation.fromMap(Map<String, dynamic> map) {
    return Moderation(
      status: map['status'] ?? 'active',
      reportCount: map['reportCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "status": status,
      "reportCount": reportCount,
    };
  }
}

