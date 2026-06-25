import 'package:flutter/material.dart';

class CurrentLocationButton extends StatelessWidget {
  const CurrentLocationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {},
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Icon(
            Icons.my_location,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}