import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';



class OtherUserDogPage extends StatelessWidget {
  final String targetUserId;
  final List<Dog> dogsList;
  final List<Dog>? favoriteDogs;
  final void Function(Dog)? onToggleFavorite;

  const OtherUserDogPage({
    super.key,
    required this.targetUserId,
    required this.dogsList,
    this.favoriteDogs,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final userDogs = dogsList.where((dog) => dog.ownerId == targetUserId).toList();
    final localizations = AppLocalizations.of(context)!;

    if (kDebugMode) {
      print('OtherUserDogPage - Building UI for targetUserId: $targetUserId, dogs count: ${userDogs.length}');
    }

    if (userDogs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.noDogsFound ?? 'No Dogs Found', style: GoogleFonts.poppins(color: const Color(0xFFFFC107))),
          backgroundColor: Colors.pink,
        ),
        body: Center(
          child: Text(localizations.noDogsForUser ?? 'No dogs found for this user.', style: GoogleFonts.poppins(color: const Color(0xFFFFC107))),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.dogsOfThisUser ?? 'Dogs of this User', style: GoogleFonts.poppins(color: const Color(0xFFFFC107))),
        backgroundColor: Colors.pink,
      ),
      body: Container(
        color: Colors.pink,
        child: ListView.builder(
          itemCount: userDogs.length,
          itemBuilder: (context, index) {
            final dog = userDogs[index];
            if (kDebugMode) {
              print('OtherUserDogPage - Displaying dog: ${dog.name}, ID: ${dog.id}');
            }
            return DogCard(
              key: ValueKey(dog.id),
              dog: dog,
              allDogs: dogsList,
              currentUserId: appState.currentUserId ?? '',
              favoriteDogs: favoriteDogs,
              onToggleFavorite: onToggleFavorite ?? appState.toggleFavorite,
              likers: appState.dogLikes[dog.id] ?? [],
            );
          },
        ),
      ),
    );
  }
}