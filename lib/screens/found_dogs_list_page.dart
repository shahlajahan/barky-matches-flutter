import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/found_dog.dart';
import 'found_dog_detail_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FoundDogsListPage extends StatefulWidget {
  const FoundDogsListPage({super.key});

  @override
  _FoundDogsListPageState createState() => _FoundDogsListPageState();
}

class _FoundDogsListPageState extends State<FoundDogsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateClaimedStatus(String docId, String reportedBy, bool isClaimed) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != reportedBy) return;

    try {
      await _firestore.collection('found_dogs').doc(docId).update({'isClaimed': isClaimed});
      if (kDebugMode) print('FoundDogsListPage - Updated status for docId: $docId to isClaimed: $isClaimed');

      if (isClaimed) {
        await _sendClaimedNotification(docId);
      }
    } catch (e) {
      if (kDebugMode) print('FoundDogsListPage - Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e', style: GoogleFonts.poppins(color: const Color(0xFFFFC107)))),
      );
    }
  }

  Future<void> _sendClaimedNotification(String foundDogId) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
    try {
      final snapshot = await _firestore.collection('found_dogs').doc(foundDogId).get();
      final foundDog = FoundDog.fromMap(snapshot.data() as Map<String, dynamic>).copyWith(id: foundDogId);
      final callable = functions.httpsCallable('sendNotification');
      await callable.call(<String, dynamic>{
        'title': 'Found Dog Claimed!',
        'body': '${foundDog.name} (${foundDog.breed}) has been claimed near ${foundDog.latitude}, ${foundDog.longitude}',
        'foundDogId': foundDogId,
      });
      if (kDebugMode) print('FoundDogsListPage - Claimed notification sent for docId: $foundDogId');
    } catch (e) {
      if (kDebugMode) print('FoundDogsListPage - Error sending claimed notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Found Dogs',
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFC107),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFC107)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('found_dogs')
              .orderBy('reportedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC107)),
              );
            }
            final foundDogs = snapshot.data!.docs.map((doc) {
              return FoundDog.fromMap(doc.data() as Map<String, dynamic>)
                  .copyWith(id: doc.id);
            }).toList();

            return ListView.builder(
              itemCount: foundDogs.length,
              itemBuilder: (context, index) {
                final dog = foundDogs[index];
                final user = FirebaseAuth.instance.currentUser;
                final isOwner = user?.uid == dog.reportedBy;

                return Card(
                  color: dog.isClaimed ? Colors.pink[100] : Colors.pink[50],
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FoundDogDetailPage(foundDog: dog),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: Icon(
                        Icons.pets,
                        color: dog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107),
                      ),
                      title: Text(
                        dog.name,
                        style: GoogleFonts.poppins(
                          color: dog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        dog.breed,
                        style: GoogleFonts.poppins(
                          color: dog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107),
                          fontSize: 14,
                        ),
                      ),
                      trailing: isOwner
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dog.isClaimed ? 'Claimed' : 'Not Claimed',
                                  style: GoogleFonts.poppins(
                                    color: dog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107),
                                    fontSize: 14,
                                  ),
                                ),
                                Switch(
                                  value: dog.isClaimed,
                                  onChanged: (value) {
                                    _updateClaimedStatus(dog.id, dog.reportedBy, value);
                                  },
                                  activeThumbColor: Colors.pink[300],
                                  inactiveThumbColor: Colors.pink[100],
                                ),
                              ],
                            )
                          : Text(
                              dog.isClaimed ? 'Claimed' : 'Not Claimed',
                              style: GoogleFonts.poppins(
                                color: dog.isClaimed ? Colors.pink[300] : const Color(0xFFFFC107),
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}