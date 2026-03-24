class BusinessDraft {
  final BusinessProfileDraft profile;
  final BusinessContactDraft contact;
  final BusinessLegalDraft legal;

  const BusinessDraft({
    required this.profile,
    required this.contact,
    required this.legal,
  });

  Map<String, dynamic> toJson() => {
        "profile": profile.toJson(),
        "contact": contact.toJson(),
        "legal": legal.toJson(),
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
        "categories": [],
        "tags": [],
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
        "location": null,
      };
}

class BusinessLegalDraft {
  final String taxNumber;
  final String mersisNumber;
  final bool disclaimerAccepted;

  const BusinessLegalDraft({
    required this.taxNumber,
    required this.mersisNumber,
    required this.disclaimerAccepted,
  });

  Map<String, dynamic> toJson() => {
        "taxNumber": taxNumber.trim(),
        "mersisNumber": mersisNumber.trim(),
        "documents": [],
        "disclaimerAcceptedAt": disclaimerAccepted ? DateTime.now().toIso8601String() : null,
      };
}