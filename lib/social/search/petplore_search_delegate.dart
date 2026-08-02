import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class PetploreSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search pets or users';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),

        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),

      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users_public')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.noResults));
        }

        return ListView.builder(
          itemCount: docs.length,

          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: data['photoUrl'] != null
                    ? NetworkImage(data['photoUrl'])
                    : null,
              ),

              title: Text(data['username'] ?? 'Unknown'),

              onTap: () {
                final appState = context.read<AppState>();

                final userId = docs[index].id;

                appState.setPlaymateProfile(userId, appState.allDogs);

                appState.setCurrentTab(NavTab.playmates);

                close(context, null);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context)!.searchUsersHint));
  }
}
