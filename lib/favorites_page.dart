import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final favoriteDogs = appState.favoriteDogs;
    final currentUserId = appState.currentUserId ?? '';

    final filteredFavoriteDogs = favoriteDogs
        .where((dog) => dog.ownerId != currentUserId)
        .toList();

    return Container(
  color: AppTheme.bg,
  child: SafeArea(
    top: false,
    child: filteredFavoriteDogs.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            itemCount: filteredFavoriteDogs.length,
            itemBuilder: (context, index) {
              final dog = filteredFavoriteDogs[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DogCard(
                  key: ValueKey(dog.id),
                  dog: dog,
                  mode: DogCardMode.compact,
                  allDogs: appState.allDogs,
                  currentUserId: currentUserId,
                  favoriteDogs: appState.favoriteDogs,
                  onToggleFavorite: appState.toggleFavorite,
                  likers: appState.dogLikes[dog.id] ?? [],
                ),
              );
            },
          ),
  ),
);
  }

  Widget _buildEmptyState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 💗 Soft Heart Icon (Brand Accent)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.08),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 48,
              color: AppTheme.primary.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 24),

          // 🐾 Title
          Text(
            "No tail-wagging crushes yet 🐾",
            textAlign: TextAlign.center,
            style: AppTheme.h2(),
          ),

          const SizedBox(height: 10),

          // 💬 Subtitle
          Text(
            "When you find a pup you adore,\ntap the heart and they’ll live here.",
            textAlign: TextAlign.center,
            style: AppTheme.body(color: AppTheme.muted),
          ),

          const SizedBox(height: 28),

          // ✨ Soft hint badge (like Playdate Accepted style)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.card.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Go explore Playmates 💛",
              style: AppTheme.caption(
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}