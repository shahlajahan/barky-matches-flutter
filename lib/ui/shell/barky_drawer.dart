import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../dog.dart';
import '../../user_profile_page.dart';
import '../../adoption_page.dart';
import '../../screens/lost_dogs_list_page.dart';
import '../../screens/found_dogs_list_page.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

class BarkyDrawer extends StatelessWidget {
  final String currentUserId;
  final List<Dog> dogs;
  final List<Dog> favoriteDogs;
  final void Function(Dog) onToggleFavorite;

  const BarkyDrawer({
    super.key,
    required this.currentUserId,
    required this.dogs,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 240,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.pink),
            child: Text(
              'Menu',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFC107),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          _pushNamed(context, Icons.home, 'Playmates', '/playmate'),

          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('My Dogs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(
                    userId: currentUserId,
                    dogs: dogs,
                    favoriteDogs: favoriteDogs,
                    onToggleFavorite: onToggleFavorite,
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Adoption Center'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdoptionPage(
                    dogs: dogs,
                    favoriteDogs: favoriteDogs,
                    onToggleFavorite: onToggleFavorite,
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.park),
            title: const Text('Dog Parks'),
            onTap: () {
              Navigator.pop(context);
              context.read<AppState>().setCurrentTab(NavTab.dogParks);
            },
          ),

          const Divider(),

          _pushNamed(context, Icons.report, 'Report Lost Dog', '/lost_dog_report'),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Lost Dogs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LostDogsListPage(),
                ),
              );
            },
          ),

          _pushNamed(context, Icons.report, 'Report Found Dog', '/found_dog_report'),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Found Dogs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FoundDogsListPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _pushNamed(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
