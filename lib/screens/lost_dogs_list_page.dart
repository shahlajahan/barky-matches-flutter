import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/lost_dog.dart';
import 'lost_dog_detail_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LostDogsListPage extends StatefulWidget {
  const LostDogsListPage({super.key});

  @override
  _LostDogsListPageState createState() => _LostDogsListPageState();
}

class _LostDogsListPageState extends State<LostDogsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateFoundStatus(String docId, String reportedBy, bool isFound) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != reportedBy) return;

    try {
      await _firestore.collection('lost_dogs').doc(docId).update({'isFound': isFound});
      if (kDebugMode) print('LostDogsListPage - Updated status for docId: $docId to isFound: $isFound');

      if (isFound) {
        await _sendFoundNotification(docId);
      }
    } catch (e) {
      if (kDebugMode) print('LostDogsListPage - Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e', style: GoogleFonts.poppins(color: const Color(0xFFFFC107)))),
      );
    }
  }

  Future<void> _sendFoundNotification(String lostDogId) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
    try {
      final snapshot = await _firestore.collection('lost_dogs').doc(lostDogId).get();
      final lostDog = LostDog.fromMap(snapshot.data() as Map<String, dynamic>).copyWith(id: lostDogId);
      final callable = functions.httpsCallable('sendNotification');
      await callable.call(<String, dynamic>{
        'title': 'Lost Dog Found!',
        'body': '${lostDog.name} (${lostDog.breed}) has been found near ${lostDog.latitude}, ${lostDog.longitude}',
        'lostDogId': lostDogId,
      });
      if (kDebugMode) print('LostDogsListPage - Found notification sent for docId: $lostDogId');
    } catch (e) {
      if (kDebugMode) print('LostDogsListPage - Error sending found notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lost Dogs',
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
              .collection('lost_dogs')
              .orderBy('reportedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC107)),
              );
            }
            final lostDogs = snapshot.data!.docs.map((doc) {
              return LostDog.fromMap(doc.data() as Map<String, dynamic>)
                  .copyWith(id: doc.id);
            }).toList();

            return ListView.builder(
              itemCount: lostDogs.length,
              itemBuilder: (context, index) {
                final dog = lostDogs[index];
                final user = FirebaseAuth.instance.currentUser;
                final isOwner = user?.uid == dog.reportedBy;

                return Card(
                  color: dog.isFound ? Colors.pink[100] : Colors.pink[50],
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LostDogDetailPage(lostDog: dog),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: Icon(
                        Icons.pets,
                        color: dog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                      ),
                      title: Text(
                        dog.name,
                        style: GoogleFonts.poppins(
                          color: dog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        dog.breed,
                        style: GoogleFonts.poppins(
                          color: dog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                          fontSize: 14,
                        ),
                      ),
                      trailing: isOwner
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dog.isFound ? 'Found' : 'Not Found',
                                  style: GoogleFonts.poppins(
                                    color: dog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
                                    fontSize: 14,
                                  ),
                                ),
                                Switch(
                                  value: dog.isFound,
                                  onChanged: (value) {
                                    _updateFoundStatus(dog.id, dog.reportedBy, value);
                                  },
                                  activeThumbColor: Colors.pink[300],
                                  inactiveThumbColor: Colors.pink[100],
                                ),
                              ],
                            )
                          : Text(
                              dog.isFound ? 'Found' : 'Not Found',
                              style: GoogleFonts.poppins(
                                color: dog.isFound ? Colors.pink[300] : const Color(0xFFFFC107),
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