import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

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
    final appState = context.watch<AppState>();
    final localizations = AppLocalizations.of(context)!;

    final userDogs =
        dogsList.where((dog) => dog.ownerId == targetUserId).toList();

    // ─────────────────────────
    // 🧱 Empty State
    // ─────────────────────────
    if (userDogs.isEmpty) {
      return Container(
        color: AppTheme.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets,
                size: 56,
                color: AppTheme.muted.withOpacity(0.6),
              ),
              const SizedBox(height: 10),
              Text(
                localizations.noDogsForUser ??
                    'No dogs found for this user.',
                style: AppTheme.h2(
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─────────────────────────
    // 🐶 Main Page
    // ─────────────────────────
    return Container(
      color: AppTheme.bg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 🔙 Header (Vet style spacing)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: AppTheme.primary,
                    onPressed: () {
                      context
                          .read<AppState>()
                          .closePlaymateProfile();
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    localizations.dogsOfThisUser ??
                        "Dogs of this User",
                    style: AppTheme.h1(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: userDogs.length,
                itemBuilder: (context, index) {
                  final dog = userDogs[index];

                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: DogCard(
                      key: ValueKey(dog.id),
                      dog: dog,
                      mode: DogCardMode.normal,
                      allDogs: dogsList,
                      currentUserId:
                          appState.currentUserId ?? '',
                      favoriteDogs: favoriteDogs,
                      onToggleFavorite:
                          onToggleFavorite ??
                              appState.toggleFavorite,
                      likers:
                          appState.dogLikes[dog.id] ?? [],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}