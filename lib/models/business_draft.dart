class BusinessDraft {
  final List<String> sectors; // 🔥 NEW

  final BusinessProfileDraft profile;
  final BusinessContactDraft contact;
  final BusinessLegalDraft legal;

  final Map<String, dynamic> sectorData; // 🔥 NEW

  const BusinessDraft({
    required this.sectors,
    required this.profile,
    required this.contact,
    required this.legal,
    required this.sectorData,
  });

  BusinessDraft copyWith({
    List<String>? sectors,
    BusinessProfileDraft? profile,
    BusinessContactDraft? contact,
    BusinessLegalDraft? legal,
    Map<String, dynamic>? sectorData,
  }) {
    return BusinessDraft(
      sectors: sectors ?? this.sectors,
      profile: profile ?? this.profile,
      contact: contact ?? this.contact,
      legal: legal ?? this.legal,
      sectorData: sectorData ?? this.sectorData,
    );
  }

  Map<String, dynamic> toJson() => {
    "sectors": sectors,
    "profile": profile.toJson(),
    "contact": contact.toJson(),
    "legal": legal.toJson(),
    "sectorData": sectorData,
  };
}

class BusinessProfileDraft {
  final String displayName;
  final String description;
  final String? logoUrl;
  final String? coverUrl;

  const BusinessProfileDraft({
    required this.displayName,
    required this.description,
    this.logoUrl,
    this.coverUrl,
  });

  Map<String, dynamic> toJson() => {
    "displayName": displayName.trim(),
    "description": description.trim(),
    "logoUrl": logoUrl,
    "coverUrl": coverUrl,
  };
}

class BusinessContactDraft {
  final String phone;
  final String whatsapp;
  final String email;
  final String instagram;
  final String website;
  final String city;
  final String district;
  final String addressLine;

  const BusinessContactDraft({
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.instagram,
    required this.website,
    required this.city,
    required this.district,
    required this.addressLine,
  });

  Map<String, dynamic> toJson() => {
    "phone": phone.trim(),
    "whatsapp": whatsapp.trim(),
    "email": email.trim(),
    "instagram": instagram.trim(),
    "website": website.trim(),
    "city": city.trim(),
    "district": district.trim(),
    "addressLine": addressLine.trim(),
    "location": null, // بعداً GeoPoint
  };
}

class BusinessLegalDraft {
  final String taxNumber;
  final String mersisNumber;
  final bool disclaimerAccepted;
  final String? disclaimerVersion;
  final String? disclaimerAcceptedAt;

  const BusinessLegalDraft({
    required this.taxNumber,
    required this.mersisNumber,
    required this.disclaimerAccepted,
    this.disclaimerVersion,
    this.disclaimerAcceptedAt,
  });

  Map<String, dynamic> toJson() => {
    "taxNumber": taxNumber.trim(),
    "mersisNumber": mersisNumber.trim(),
    "documents": [],
    "disclaimerAccepted": disclaimerAccepted,
    "disclaimerVersion": disclaimerVersion,
    "disclaimerAcceptedAt": disclaimerAcceptedAt,
  };
}
