import 'package:flutter/material.dart';
import '../../dog.dart';
import '../../dog_card.dart';

class PreviewDogsSection extends StatelessWidget {
  final List<Dog> previewDogs;

  const PreviewDogsSection({
    super.key,
    required this.previewDogs,
  });

  @override
  Widget build(BuildContext context) {
    if (previewDogs.isEmpty) {
      return const Text(
        "No dogs yet — add yours and start matching! 🐾",
        style: TextStyle(color: Color(0xFF9E1B4F),),
      );
    }

    return Column(
      children: previewDogs.take(3).map((dog) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DogCard(
            dog: dog,
            allDogs: previewDogs,
            currentUserId: '',
            likers: const [],
            favoriteDogs: const [],
            selectedRequesterDogId: null,
            mode: DogCardMode.compact,

            // 🔥 فقط اینو نگه دار
            onCardTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Create profile to connect 🐾"),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}