import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'blocked_users_page.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {

  bool profileVisible = true;
  bool locationSharing = true;
  bool dogProfileVisible = true;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  /// LOAD SETTINGS FROM FIRESTORE
  Future<void> _loadPrivacySettings() async {

    try {

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      final data = doc.data();

      if (data != null) {

        profileVisible = data["profileVisible"] ?? true;
        locationSharing = data["locationSharing"] ?? true;
        dogProfileVisible = data["dogProfileVisible"] ?? true;

      }

    } catch (e) {
      debugPrint("Privacy load error: $e");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  /// SAVE SETTINGS
  Future<void> _savePrivacySettings() async {

  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) return;

  final db = FirebaseFirestore.instance;

  /// update user
  await db.collection("users").doc(uid).set({
    "profileVisible": profileVisible,
    "locationSharing": locationSharing,
    "dogProfileVisible": dogProfileVisible,
  }, SetOptions(merge: true));

  /// update all dogs of user
  final dogs = await db
      .collection("dogs")
      .where("ownerId", isEqualTo: uid)
      .get();

  for (final doc in dogs.docs) {

    await doc.reference.update({
      "ownerProfileVisible": profileVisible,
      "dogProfileVisible": dogProfileVisible,
    });

  }
}
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppTheme.bg,

      appBar: AppBar(
        title: const Text("Privacy Settings"),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),

      body: Stack(

        children: [

          ListView(
            padding: const EdgeInsets.all(20),
            children: [

              _SectionTitle("Profile"),

              _ToggleTile(
                title: "Profile visibility",
                subtitle: profileVisible
                    ? "Other users can see your profile"
                    : "Your profile is hidden",
                value: profileVisible,
                onChanged: (v){
                  setState(() {
                    profileVisible = v;
                  });
                  _savePrivacySettings();
                },
              ),

              _ToggleTile(
                title: "Location sharing",
                subtitle: locationSharing
                    ? "Your approximate location is visible"
                    : "Your location is hidden",
                value: locationSharing,
                onChanged: (v){
                  setState(() {
                    locationSharing = v;
                  });
                  _savePrivacySettings();
                },
              ),

              const SizedBox(height: 20),

              _SectionTitle("Dogs"),

              _ToggleTile(
                title: "Dog profile visibility",
                subtitle: dogProfileVisible
                    ? "Other users can see your dogs"
                    : "Your dogs are hidden",
                value: dogProfileVisible,
                onChanged: (v){
                  setState(() {
                    dogProfileVisible = v;
                  });
                  _savePrivacySettings();
                },
              ),

              const SizedBox(height: 30),

              _SectionTitle("Account"),

              _ActionTile(
  title: "Blocked users",
  icon: Icons.block,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BlockedUsersPage(),
      ),
    );
  },
),

              _ActionTile(
                title: "Download my data",
                icon: Icons.download,
                onTap: (){
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Data export request submitted"),
    ),
  );
}
              ),

              _ActionTile(
                title: "Delete account",
                icon: Icons.delete,
                danger: true,
                onTap: (){
                  _showDeleteDialog();
                },
              ),
            ],
          ),

          if (loading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )

        ],
      ),
    );
  }

  void _showDeleteDialog(){

    showDialog(
      context: context,
      builder: (_){

        return AlertDialog(

          title: const Text("Delete account"),

          content: const Text(
              "This action cannot be undone."
          ),

          actions: [

            TextButton(
              onPressed: ()=>Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: (){
                Navigator.pop(context);
              },
              child: const Text("Delete"),
            )

          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {

  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {

  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),

      child: SwitchListTile(

        title: Text(title),

        subtitle: Text(subtitle),

        value: value,

        activeColor: AppTheme.primary,

        onChanged: onChanged,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),

      child: ListTile(

        leading: Icon(
          icon,
          color: danger ? Colors.red : AppTheme.primary,
        ),

        title: Text(
          title,
          style: TextStyle(
            color: danger ? Colors.red : Colors.black,
          ),
        ),

        trailing: const Icon(Icons.chevron_right),

        onTap: onTap,
      ),
    );
  }
}