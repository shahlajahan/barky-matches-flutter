import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class EditPetHotelProfilePage extends StatefulWidget {
  final String businessId;

  const EditPetHotelProfilePage({
    super.key,
    required this.businessId,
  });

  @override
  State<EditPetHotelProfilePage> createState() =>
      _EditPetHotelProfilePageState();
}

class _EditPetHotelProfilePageState
    extends State<EditPetHotelProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _hotelNameController =
      TextEditingController();

  final _bioController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _whatsappController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _websiteController =
      TextEditingController();

  final _instagramController =
      TextEditingController();

  final _cityController =
      TextEditingController();

  final _districtController =
      TextEditingController();

  final _workingHoursController =
      TextEditingController();

  bool _loading = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection("businesses")
              .doc(widget.businessId)
              .get();

      final data =
          doc.data() ?? {};

      final profile =
          Map<String, dynamic>.from(
        data["profile"] ?? {},
      );

      final contact =
          Map<String, dynamic>.from(
        data["contact"] ?? {},
      );

      final sectorData =
          Map<String, dynamic>.from(
        data["sectorData"] ?? {},
      );

      final hotelData =
          Map<String, dynamic>.from(
        sectorData["pet_hotel"] ??
            sectorData["hotel"] ??
            sectorData["petHotel"] ??
            {},
      );

      final hotelProfile =
          Map<String, dynamic>.from(
        hotelData["profile"] ?? {},
      );

      final profileContent =
          Map<String, dynamic>.from(
        hotelData["profileContent"] ??
            {},
      );

      final socialMedia =
          Map<String, dynamic>.from(
        profileContent["socialMedia"] ??
            {},
      );

      _hotelNameController.text =
          (
            profile["displayName"] ??
            profile["businessName"] ??
            hotelData["hotelName"] ??
            hotelData["businessName"] ??
            ""
          ).toString();

      _bioController.text =
          (
            profile["bio"] ??
            profile["description"] ??
            hotelProfile["bio"] ??
            hotelData["description"] ??
            ""
          ).toString();

      _phoneController.text =
          (contact["phone"] ?? "")
              .toString();

      _whatsappController.text =
          (contact["whatsapp"] ?? "")
              .toString();

      _emailController.text =
          (contact["email"] ?? "")
              .toString();

      _websiteController.text =
          (contact["website"] ?? "")
              .toString();

      _instagramController.text =
          (
            socialMedia[
                    "instagram"] ??
                hotelProfile[
                    "instagram"] ??
                hotelData[
                    "instagram"] ??
                contact[
                    "instagram"] ??
                ""
          ).toString();

      _cityController.text =
          (contact["city"] ?? "")
              .toString();

      _districtController.text =
          (contact["district"] ?? "")
              .toString();

      _workingHoursController.text =
          (
            hotelData[
                    "workingHours"] ??
                ""
          ).toString();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text("Load error: $e"),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection("businesses")
          .doc(widget.businessId)
          .set({
        "profile": {
          "displayName":
              _hotelNameController.text
                  .trim(),

          "businessName":
              _hotelNameController.text
                  .trim(),

          "bio":
              _bioController.text
                  .trim(),

          "description":
              _bioController.text
                  .trim(),

          "updatedAt":
              FieldValue
                  .serverTimestamp(),
        },

        "contact": {
          "phone":
              _phoneController.text
                  .trim(),

          "whatsapp":
              _whatsappController.text
                  .trim(),

          "email":
              _emailController.text
                  .trim(),

          "website":
              _websiteController.text
                  .trim(),

          "instagram":
              _instagramController.text
                  .trim(),

          "city":
              _cityController.text
                  .trim(),

          "district":
              _districtController.text
                  .trim(),

          "updatedAt":
              FieldValue
                  .serverTimestamp(),
        },

        "sectorData": {
          "pet_hotel": {
            "hotelName":
                _hotelNameController.text
                    .trim(),

            "workingHours":
                _workingHoursController
                    .text
                    .trim(),

            "description":
                _bioController.text
                    .trim(),

            "profile": {
              "bio":
                  _bioController.text
                      .trim(),

              "instagram":
                  _instagramController
                      .text
                      .trim(),
            },

            "profileContent": {
              "bio":
                  _bioController.text
                      .trim(),

              "socialMedia": {
                "instagram":
                    _instagramController
                        .text
                        .trim(),
              },
            },

            "updatedAt":
                FieldValue
                    .serverTimestamp(),
          }
        },

        "updatedAt":
            FieldValue.serverTimestamp(),
      },
              SetOptions(
                merge: true,
              ));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Profile updated successfully",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text("Save error: $e"),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)?
        validator,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration:
            InputDecoration(
          labelText: label,

          filled: true,

          fillColor:
              Colors.white,

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hotelNameController.dispose();

    _bioController.dispose();

    _phoneController.dispose();

    _whatsappController.dispose();

    _emailController.dispose();

    _websiteController.dispose();

    _instagramController.dispose();

    _cityController.dispose();

    _districtController.dispose();

    _workingHoursController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppTheme.bg,

      appBar: AppBar(
        title: const Text(
          "Edit Hotel Profile",
        ),
      ),

      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,

              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),

                children: [

                  _field(
                    _hotelNameController,
                    "Hotel Name",

                    validator: (v) {
                      if (v == null ||
                          v.trim()
                              .isEmpty) {
                        return "Hotel name is required";
                      }

                      return null;
                    },
                  ),

                  _field(
                    _bioController,
                    "About / Bio",
                    maxLines: 4,
                  ),

                  _field(
                    _phoneController,
                    "Phone",
                  ),

                  _field(
                    _whatsappController,
                    "WhatsApp",
                  ),

                  _field(
                    _emailController,
                    "Email",
                  ),

                  _field(
                    _websiteController,
                    "Website",
                  ),

                  _field(
                    _instagramController,
                    "Instagram",
                  ),

                  _field(
                    _cityController,
                    "City",
                  ),

                  _field(
                    _districtController,
                    "District",
                  ),

                  _field(
                    _workingHoursController,
                    "Working Hours",
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  ElevatedButton(
                    onPressed:
                        _saving
                            ? null
                            : _save,

                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,

                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Text(
                            "Save",
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}