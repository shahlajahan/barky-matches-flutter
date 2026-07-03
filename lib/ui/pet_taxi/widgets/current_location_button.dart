import 'package:flutter/material.dart';

class CurrentLocationButton extends StatelessWidget {
  final VoidCallback onTap;

  const CurrentLocationButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Icon(Icons.my_location, color: Colors.black87),
        ),
      ),
    );
  }
}
