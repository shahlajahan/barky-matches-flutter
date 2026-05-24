import 'package:flutter/material.dart';

class AddAdoptionPetDetailPage
    extends StatelessWidget {

  final String businessId;

  final String petTitle;

  final String? petId;

  final Map<String, dynamic>?
      existingData;

  const AddAdoptionPetDetailPage({
    super.key,
    required this.businessId,
    required this.petTitle,
    this.petId,
    this.existingData,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(
          petId == null
              ? 'Add Adoption Pet'
              : 'Edit Adoption Pet',
        ),
      ),

      body: Center(
        child: Text(
          petTitle,
        ),
      ),
    );
  }
}