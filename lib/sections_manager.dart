import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';



class SectionsManager {
  static Widget buildPlaymateSection(
    BuildContext context,
    Box<Dog> dogsBox,
    List<Dog> filteredDogs,
    Function(Dog) onToggleFavorite,
    String currentUserId,
    Map<String, List<Map<String, dynamic>>> dogLikes,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return filteredDogs.isEmpty
        ? Center(
            child: Text(
              localizations.noDogsMatchFilters ?? 'No dogs match your filters.',
              style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16),
            ),
          )
        : ListView.builder(
            cacheExtent: 1000.0,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: filteredDogs.length,
            itemBuilder: (context, index) {
              final dog = filteredDogs[index];
              if (kDebugMode) {
                print(
                    'SectionsManager - Displaying dog at index $index: Name=${dog.name}, Breed=${dog.breed}, Age=${dog.age}, Gender=${dog.gender}');
              }
              return RepaintBoundary(
                child: DogCard(
                  key: ValueKey('${dog.ownerId ?? 'unknown'}_${dog.name.trim()}'),
                  dog: dog,
                  allDogs: filteredDogs, // اضافه کردن allDogs
                  currentUserId: currentUserId,
                  favoriteDogs: AppState.of(context).favoriteDogs ?? [],
                  onToggleFavorite: onToggleFavorite,
                  onDogUpdated: (updatedDog) {},
                  likers: dogLikes['${dog.name}_${dog.ownerId ?? 'unknown'}'] ?? [],
                ),
              );
            },
          );
  }

  static Widget buildMyDogsSection(
    BuildContext context,
    Box<Dog> dogsBox,
    List<Dog> userDogs,
    Function(Dog) onToggleFavorite,
    String currentUserId,
    Map<String, List<Map<String, dynamic>>> dogLikes,
  ) {
    final localizations = AppLocalizations.of(context)!;
    if (userDogs.isEmpty) {
      return Center(
        child: Text(
          localizations.noDogsAddedYet ?? 'No dogs added yet.',
          style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: userDogs.length,
      itemBuilder: (context, index) {
        final dog = userDogs[index];
        return RepaintBoundary(
          child: DogCard(
            key: ValueKey('${dog.ownerId ?? 'unknown'}_${dog.name.trim()}'),
            dog: dog,
            allDogs: userDogs, // اضافه کردن allDogs
            currentUserId: currentUserId,
            favoriteDogs: AppState.of(context).favoriteDogs ?? [],
            onToggleFavorite: onToggleFavorite,
            onDogUpdated: (updatedDog) {},
            likers: dogLikes['${dog.name}_${dog.ownerId ?? 'unknown'}'] ?? [],
          ),
        );
      },
    );
  }

  static Widget buildFavoritesSection(
    BuildContext context,
    Box<Dog> favoritesBox,
    Function(Dog) onToggleFavorite,
    String currentUserId,
    Map<String, List<Map<String, dynamic>>> dogLikes,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final favoriteDogs = favoritesBox.values.toList();
    if (kDebugMode) {
      print('SectionsManager - Favorite dogs count: ${favoriteDogs.length}');
      for (var dog in favoriteDogs) {
        print('SectionsManager - Favorite dog: ${dog.name}, ownerId: ${dog.ownerId}');
      }
    }
    return favoriteDogs.isEmpty
        ? Center(
            child: Text(
              localizations.noFavoriteDogsYet ?? 'No favorite dogs yet.',
              style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: favoriteDogs.length,
            itemBuilder: (context, index) {
              final dog = favoriteDogs[index];
              return RepaintBoundary(
                child: DogCard(
                  key: ValueKey('${dog.ownerId ?? 'unknown'}_${dog.name.trim()}'),
                  dog: dog,
                  allDogs: favoriteDogs, // اضافه کردن allDogs
                  currentUserId: currentUserId,
                  favoriteDogs: favoriteDogs,
                  onToggleFavorite: onToggleFavorite,
                  onDogUpdated: (updatedDog) {},
                  likers: dogLikes['${dog.name}_${dog.ownerId ?? 'unknown'}'] ?? [],
                ),
              );
            },
          );
  }
}