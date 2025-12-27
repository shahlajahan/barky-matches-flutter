import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';
import 'dog_view_page.dart';
import 'app_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
 // اضافه کردن برای محلی‌سازی

class FavoritesPage extends StatefulWidget {
  final List<Dog> favoriteDogs;
  final List<Dog> dogsList;
  final Function(Dog) onToggleFavorite;

  const FavoritesPage({
    super.key,
    required this.favoriteDogs,
    required this.dogsList,
    required this.onToggleFavorite,
  });

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Box<Dog> favoritesBox;

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box<Dog>('favoritesBox');
    print('FavoritesPage - Initial favorite dogs count: ${widget.favoriteDogs.length}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // دسترسی به متن‌های محلی‌سازی‌شده
    final currentUserId = Hive.box<String>('currentUserBox').get('currentUserId');

    return ValueListenableBuilder<List<Dog>>(
      valueListenable: AppState.of(context).favoriteDogsNotifier,
      builder: (context, favoriteDogs, child) {
        final filteredFavoriteDogs = favoriteDogs
            .where((dog) => dog.ownerId != currentUserId)
            .toList();

        print('FavoritesPage - Favorite dogs count: ${filteredFavoriteDogs.length}');
        for (var dog in filteredFavoriteDogs) {
          print('FavoritesPage - Favorite dog: ${dog.name}, ownerId: ${dog.ownerId}');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.favoritesPageTitle, // به جای 'Favorite Dogs'
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.pink[400],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: filteredFavoriteDogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/image/sad_dog.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noFavoriteDogsYet, // به جای 'No favorite dogs yet!'
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.addFavoriteSuggestion, // به جای 'Go back to the home page and add some dogs to your favorites.'
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemExtent: 100,
                    itemCount: filteredFavoriteDogs.length,
                    itemBuilder: (context, index) {
                      final dog = filteredFavoriteDogs[index];
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.pink[100],
                            child: dog.imagePaths.isNotEmpty &&
                                    dog.imagePaths[0].isNotEmpty &&
                                    dog.imagePaths[0].startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: dog.imagePaths[0],
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(color: Colors.white),
                                    errorWidget: (context, url, error) {
                                      print('FavoritesPage - Error loading image for ${dog.name}: $error');
                                      return const Image(
                                        image: AssetImage('assets/image/default_dog.png'),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                    fit: BoxFit.cover,
                                    width: 50,
                                    height: 50,
                                  )
                                : const Image(
                                    image: AssetImage('assets/image/default_dog.png'),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          title: Text(
                            dog.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            dog.breed,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DogViewPage(
                                  dog: dog,
                                  favoriteDogs: filteredFavoriteDogs,
                                  onToggleFavorite: AppState.of(context).toggleFavorite,
                                ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            tooltip: l10n.removeFavoriteTooltip, // به جای 'Remove Favorite'
                            onPressed: () {
                              AppState.of(context).toggleFavorite(dog);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}