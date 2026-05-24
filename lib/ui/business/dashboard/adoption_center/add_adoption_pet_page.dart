import 'package:flutter/material.dart';

class AddAdoptionPetPage extends StatelessWidget {

  final List<String> pets;

final String title;

final String sectionTitle;

final IconData fallbackIcon;

  const AddAdoptionPetPage({
  super.key,
  required this.pets,
  required this.title,
  required this.sectionTitle,
  required this.fallbackIcon,
});

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}