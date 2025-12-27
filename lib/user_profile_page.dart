import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'add_dog_page.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'globals.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';


Future<void> ensureFirebase() async {
  if (Firebase.apps.isEmpty) {
    print('UserProfilePage - Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('UserProfilePage - Firebase initialized successfully');
  }
}

class UserInfo {
  final String username;
  final String email;
  final String phone;
  final String password;

  UserInfo({
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'phone': phone,
      'password': password,
    };
  }

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      username: map['username'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      password: map['password'] as String,
    );
  }
}

class UserProfilePage extends StatefulWidget {
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
  final Function(Dog)? onDogAdded;
  final String userId;

  const UserProfilePage({
    super.key,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
    this.onDogAdded,
    required this.userId,
  });

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late List<Dog> _userDogs;
  late List<Dog> _adoptionDogs;
  late Box<String> userBox;
  late String _currentUserId;
  late Box<Dog> dogsBox;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = true;
  List<Dog> _cachedUserDogs = [];
  List<Dog> _cachedAdoptionDogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _initializeData();
  }

  Future<void> _initializeData() async {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    });
    userBox = Hive.box<String>('currentUserBox');
    dogsBox = Hive.box<Dog>('dogsBox');
    _currentUserId = userBox.get('currentUserId') ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    print('UserProfilePage - Current userId: $_currentUserId');
    print('UserProfilePage - Profile userId: ${widget.userId}');

    if (_currentUserId.isEmpty) {
      print('UserProfilePage - No currentUserId found, redirecting to login');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.userNotLoggedIn)),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
        }
      });
      return;
    }

    await _fixDogsWithNullOwnerId();
    await _loadUserInfo();
    await _loadUserDogs();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _fixDogsWithNullOwnerId() async {
    try {
      final dogsToFix = dogsBox.values.where((dog) => dog.ownerId == null || dog.ownerId!.isEmpty).toList();
      for (var dog in dogsToFix) {
        final updatedDog = dog.copy(ownerId: _currentUserId);
        await dogsBox.put(dog.id, updatedDog);
        await FirebaseFirestore.instance.collection('dogs').doc(dog.id).set({
          'id': dog.id,
          'name': updatedDog.name,
          'breed': updatedDog.breed,
          'age': updatedDog.age,
          'gender': updatedDog.gender,
          'healthStatus': updatedDog.healthStatus,
          'isNeutered': updatedDog.isNeutered,
          'description': updatedDog.description,
          'traits': updatedDog.traits,
          'ownerGender': updatedDog.ownerGender,
          'imagePaths': updatedDog.imagePaths,
          'isAvailableForAdoption': updatedDog.isAvailableForAdoption,
          'isOwner': updatedDog.isOwner,
          'ownerId': updatedDog.ownerId,
          'latitude': updatedDog.latitude,
          'longitude': updatedDog.longitude,
        });
        print('UserProfilePage - Fixed ownerId for dog ${dog.name}, ID: ${dog.id} to $_currentUserId');
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('dogs')
          .where('ownerId', isNull: true)
          .get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
        print('UserProfilePage - Deleted dog with null ownerId from Firestore: ${doc.id}');
      }
    } catch (e) {
      print('UserProfilePage - Error fixing dogs with null ownerId: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    print('UserProfilePage - Available keys in userDataBox: ${userDataBox.keys}');
    print('UserProfilePage - Loading user info for userId: ${widget.userId}');

    try {
      final lowerCaseUserId = widget.userId.toLowerCase();
      if (lowerCaseUserId != widget.userId && userDataBox.containsKey(lowerCaseUserId)) {
        await userDataBox.delete(lowerCaseUserId);
        print('UserProfilePage - Deleted lowercase userId from userDataBox: $lowerCaseUserId');
      }

      final cachedData = userDataBox.get(widget.userId);
      if (cachedData != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _usernameController.text = cachedData['username'] ?? AppLocalizations.of(context)!.unknownUser;
              _emailController.text = cachedData['email'] ?? '';
              _phoneController.text = cachedData['phone']?.isEmpty ?? true ? AppLocalizations.of(context)!.notProvided : cachedData['phone'] ?? AppLocalizations.of(context)!.notProvided;
            });
          }
        });
        print('UserProfilePage - Loaded user info from Hive: $cachedData');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        userDataBox.put(widget.userId, data);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _usernameController.text = data['username'] ?? AppLocalizations.of(context)!.unknownUser;
              _emailController.text = data['email'] ?? '';
              _phoneController.text = data['phone']?.isEmpty ?? true ? AppLocalizations.of(context)!.notProvided : data['phone'] ?? AppLocalizations.of(context)!.notProvided;
            });
          }
        });
        print('UserProfilePage - Loaded user info from Firestore: $data');
      } else {
        print('UserProfilePage - No user data found in Firestore for userId: ${widget.userId}');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _usernameController.text = AppLocalizations.of(context)!.unknownUser;
              _emailController.text = '';
              _phoneController.text = AppLocalizations.of(context)!.notProvided;
            });
          }
        });
      }
    } catch (e) {
      print('UserProfilePage - Error loading user info: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _usernameController.text = AppLocalizations.of(context)!.unknownUser;
            _emailController.text = '';
            _phoneController.text = AppLocalizations.of(context)!.notProvided;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUserInfo(e.toString()))),
          );
        }
      });
    }
  }

  Future<void> _loadUserDogs() async {
    print('UserProfilePage - Loading user dogs for userId: ${widget.userId}');
    final uniqueDogs = <String, Dog>{};

    try {
      final dogsSnapshot = await FirebaseFirestore.instance
          .collection('dogs')
          .where('ownerId', isEqualTo: widget.userId)
          .limit(5)
          .get();
      for (var doc in dogsSnapshot.docs) {
        final data = doc.data();
        final dog = Dog(
          id: doc.id,
          name: data['name']?.trim() ?? doc.id,
          breed: data['breed'] ?? '',
          age: data['age'] ?? 0,
          gender: data['gender'] ?? '',
          healthStatus: data['healthStatus'] ?? '',
          isNeutered: data['isNeutered'] ?? false,
          description: data['description'] ?? '',
          traits: List<String>.from(data['traits'] ?? []),
          ownerGender: data['ownerGender'] ?? '',
          imagePaths: List<String>.from(data['imagePaths'] ?? []),
          isAvailableForAdoption: data['isAvailableForAdoption'] ?? false,
          isOwner: data['isOwner'] ?? false,
          ownerId: data['ownerId'] ?? '',
          latitude: data['latitude']?.toDouble(),
          longitude: data['longitude']?.toDouble(),
        );
        if (!uniqueDogs.containsKey(dog.id)) {
          uniqueDogs[dog.id] = dog;
          print('UserProfilePage - Loaded dog from Firestore: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
        } else {
          print('UserProfilePage - Skipped duplicate dog from Firestore: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
          await FirebaseFirestore.instance.collection('dogs').doc(doc.id).delete();
          print('UserProfilePage - Deleted duplicate dog from Firestore: ${doc.id}');
        }
      }

      final existingKeys = dogsBox.keys.cast<String>().toList();
      for (var key in existingKeys) {
        if (!uniqueDogs.containsKey(key)) {
          await dogsBox.delete(key);
          print('UserProfilePage - Deleted stale dog from Hive: $key');
        }
      }

      for (final entry in uniqueDogs.entries) {
        await dogsBox.put(entry.key, entry.value);
      }

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _userDogs = uniqueDogs.values
                .where((dog) => dog.ownerId == widget.userId && !dog.isAvailableForAdoption)
                .toList();
            _adoptionDogs = uniqueDogs.values.where((dog) => dog.isAvailableForAdoption).toList();
            _cachedUserDogs = List.from(_userDogs);
            _cachedAdoptionDogs = List.from(_adoptionDogs);
            print('UserProfilePage - Loaded ${_userDogs.length} dogs for userId: ${widget.userId}');
          });
        }
      });
    } catch (e) {
      print('UserProfilePage - Error loading dogs: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _userDogs = [];
            _adoptionDogs = [];
            _cachedUserDogs = [];
            _cachedAdoptionDogs = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingDogs(e.toString()))),
          );
        }
      });
    }
  }

  Future<void> _saveDogToHive(Map<String, dynamic> data) async {
    final dogsBox = Hive.box<Dog>('dogsBox');
    final dog = data['dog'] as Dog;
    await dogsBox.put(dog.id, dog);
    await FirebaseFirestore.instance.collection('dogs').doc(dog.id).set({
      'id': dog.id,
      'name': dog.name,
      'breed': dog.breed,
      'age': dog.age,
      'gender': dog.gender,
      'healthStatus': dog.healthStatus,
      'isNeutered': dog.isNeutered,
      'description': dog.description,
      'traits': dog.traits,
      'ownerGender': dog.ownerGender,
      'imagePaths': dog.imagePaths,
      'isAvailableForAdoption': dog.isAvailableForAdoption,
      'isOwner': dog.isOwner,
      'ownerId': dog.ownerId,
      'latitude': dog.latitude,
      'longitude': dog.longitude,
    });
  }

  void _updateDogInHive(Dog updatedDog, int originalIndex) {
    try {
      print('UserProfilePage - Updating dog in Hive: ${updatedDog.name}, ID: ${updatedDog.id}');
      _saveDogToHive({'dog': updatedDog, 'index': originalIndex}).then((_) {
        print('UserProfilePage - Dog updated in Hive: ${updatedDog.name}, ID: ${updatedDog.id}');
        _applyFilters();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }).catchError((e) {
        print('UserProfilePage - Error updating dog in Hive: $e');
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingDog(e.toString()))),
            );
          }
        });
      });
    } catch (e) {
      print('UserProfilePage - Error updating dog in Hive: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingDog(e.toString()))),
          );
        }
      });
    }
  }

  void _applyFilters() {
    final uniqueDogs = <String, Dog>{};
    for (var dog in dogsBox.values) {
      if (!uniqueDogs.containsKey(dog.id)) {
        uniqueDogs[dog.id] = dog;
      } else {
        print('UserProfilePage - Duplicate dog found in Hive: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _userDogs = uniqueDogs.values
              .where((dog) => dog.ownerId == widget.userId && !dog.isAvailableForAdoption)
              .toList();
          _adoptionDogs = uniqueDogs.values.where((dog) => dog.isAvailableForAdoption).toList();
          _cachedUserDogs = List.from(_userDogs);
          _cachedAdoptionDogs = List.from(_adoptionDogs);
          print('UserProfilePage - Filtered user dogs count: ${_userDogs.length}, adoption dogs count: ${_adoptionDogs.length}');
        });
      }
    });
  }

  void _updateUserInfo() {
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newUsername.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.usernameCannotBeEmpty),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      });
      return;
    }

    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    final userData = {
      'username': newUsername,
      'email': newEmail,
      'phone': newPhone.isEmpty ? AppLocalizations.of(context)!.notProvided : newPhone,
      'password': userDataBox.get(_currentUserId)?['password'] ?? '',
      'isPremium': newEmail == 'durbinistanbul@gmail.com' ? true : false,
    };

    try {
      FirebaseFirestore.instance.collection('users').doc(_currentUserId).set(userData, SetOptions(merge: true));
      userDataBox.put(_currentUserId, userData);
      print('UserProfilePage - Updated user info for userId: $_currentUserId');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.profileUpdatedSuccessfully),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      });
    } catch (e) {
      print('UserProfilePage - Error updating user info: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUserInfo(e.toString()))),
          );
        }
      });
    }
  }

  void _editProfile() {
    print('UserProfilePage - Opening Edit Profile Dialog');
    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(
            localizations.editProfile,
            style: GoogleFonts.poppins(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: localizations.username,
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    print('UserProfilePage - Username field tapped, keyboard dismissed');
                  },
                ),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: localizations.email,
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    print('UserProfilePage - Email field tapped, keyboard dismissed');
                  },
                ),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: localizations.phoneNumber,
                    labelStyle: GoogleFonts.poppins(),
                    hintText: localizations.enterPhoneNumberOptional,
                  ),
                  keyboardType: TextInputType.phone,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    print('UserProfilePage - Phone field tapped, keyboard dismissed');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                localizations.cancel,
                style: GoogleFonts.poppins(),
              ),
            ),
            TextButton(
              onPressed: () {
                _updateUserInfo();
                Navigator.pop(context);
              },
              child: Text(
                localizations.save,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount() {
    print('UserProfilePage - Opening Delete Account Dialog');
    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(localizations.deleteAccount),
          content: Text(localizations.deleteAccountConfirmation),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final dogsToDelete = dogsBox.values
                      .where((dog) => dog.ownerId == _currentUserId)
                      .toList();
                  for (var dog in dogsToDelete) {
                    await dogsBox.delete(dog.id);
                    await FirebaseFirestore.instance.collection('dogs').doc(dog.id).delete();
                    print('UserProfilePage - Deleted dog: ${dog.name}, ID: ${dog.id}');
                  }

                  await userBox.clear();
                  final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
                  await userDataBox.clear();
                  print('UserProfilePage - Cleared userBox and userDataBox');

                  await FirebaseFirestore.instance.collection('users').doc(_currentUserId).delete();
                  print('UserProfilePage - Deleted user data from Firestore: $_currentUserId');

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  print('UserProfilePage - Cleared saved credentials from SharedPreferences');

                  await FirebaseAuth.instance.signOut();
                  print('UserProfilePage - Signed out from Firebase');

                  stopListeners();
                  print('UserProfilePage - Called stopListeners');

                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.accountDeleted),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/welcome',
                        (Route<dynamic> route) => false,
                      );
                    }
                  });
                } catch (e) {
                  print('UserProfilePage - Error deleting account: $e');
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations.errorDeletingAccount(e.toString()))),
                      );
                    }
                  });
                }
              },
              child: Text(
                localizations.delete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    print('UserProfilePage - Logging out...');
    try {
      FirebaseAuth.instance.signOut();
      print('UserProfilePage - Signed out from Firebase');
      final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
      final currentUserBox = Hive.box<String>('currentUserBox');
      currentUserBox.clear();
      userDataBox.clear();
      print('UserProfilePage - Cleared userBox and userDataBox');
      SharedPreferences.getInstance().then((prefs) {
        prefs.clear();
        print('UserProfilePage - Cleared saved credentials from SharedPreferences');
      });
      FirebaseFirestore.instance.terminate().then((_) {
        print('UserProfilePage - Firestore terminated');
        FirebaseFirestore.instance.clearPersistence().then((_) {
          print('UserProfilePage - Persistence cleared');
          stopListeners();
          print('UserProfilePage - Called stopListeners');
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                (Route<dynamic> route) => false,
              );
            }
          });
        });
      });
    } catch (e) {
      print('UserProfilePage - Error during logout: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorDuringLogout(e.toString()))),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    print('UserProfilePage - Building UI for userId: ${widget.userId}');
    final isOwnProfile = _currentUserId == widget.userId;
    print('UserProfilePage - isOwnProfile: $isOwnProfile');

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              isOwnProfile ? localizations.myProfile : localizations.userProfile,
              style: GoogleFonts.dancingScript(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.pink[400],
            actions: isOwnProfile
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: _editProfile,
                      tooltip: localizations.editProfileTooltip,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteAccount,
                      tooltip: localizations.deleteAccountTooltip,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      tooltip: localizations.logoutTooltip,
                    ),
                  ]
                : null,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink, Colors.pinkAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<ImageProvider?>(
                          future: _loadProfileImage(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return Center(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: snapshot.data,
                                  backgroundColor: Colors.white,
                                ),
                              );
                            }
                            return const Center(
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person, size: 50, color: Colors.pink),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations.profileInformation,
                          style: GoogleFonts.dancingScript(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${localizations.username}: ${_usernameController.text}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations.email}: ${_emailController.text}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations.phoneNumber}: ${_phoneController.text}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed: _updateUserInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.pink,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: Text(
                                localizations.updateProfile,
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          localizations.myDogs,
                          style: GoogleFonts.dancingScript(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder(
                          valueListenable: dogsBox.listenable(),
                          builder: (context, Box<Dog> box, _) {
                            print('UserProfilePage - ValueListenableBuilder triggered for My Dogs');
                            final uniqueDogs = <String, Dog>{};
                            for (var dog in box.values) {
                              if (!uniqueDogs.containsKey(dog.id)) {
                                uniqueDogs[dog.id] = dog;
                              } else {
                                print('UserProfilePage - Duplicate dog found in Hive: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
                              }
                            }
                            final userDogs = uniqueDogs.values
                                .where((dog) => dog.ownerId == widget.userId && !dog.isAvailableForAdoption)
                                .toList();
                            if (!_areDogsEqual(_cachedUserDogs, userDogs)) {
                              _cachedUserDogs = List.from(userDogs);
                              print('UserProfilePage - Updated cached user dogs: ${_cachedUserDogs.length}');
                            }
                            if (_cachedUserDogs.isEmpty) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noDogsAddedYet,
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                ),
                              );
                            }
                            return ListView.builder(
                              key: const ValueKey('user_dog_list'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cachedUserDogs.length,
                              itemBuilder: (context, index) {
                                final dog = _cachedUserDogs[index];
                                print(
                                    'UserProfilePage - Displaying user dog at index $index: Name=${dog.name}, ID=${dog.id}, Breed=${dog.breed}, OwnerId=${dog.ownerId}');
                                return DogCard(
                                  key: ValueKey(dog.id),
                                  dog: dog,
                                  allDogs: widget.dogsList,
                                  currentUserId: _currentUserId,
                                  favoriteDogs: widget.favoriteDogs,
                                  onToggleFavorite: widget.onToggleFavorite,
                                  onDogUpdated: isOwnProfile
                                      ? (updatedDog) {
                                          final originalIndex = box.values.toList().indexOf(dog);
                                          if (originalIndex != -1) {
                                            _updateDogInHive(updatedDog, originalIndex);
                                          }
                                        }
                                      : null,
                                  selectedRequesterDogId: Provider.of<AppState>(context, listen: false).selectedRequesterDogId,
                                  onRequesterDogChanged: (value) {
                                    Provider.of<AppState>(context, listen: false).setSelectedRequesterDogId(value);
                                  },
                                  onAdopt: () {
                                    SchedulerBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(localizations.adoptionRequestSent(dog.name)),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  likers: appState.dogLikes[dog.id] ?? [],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          localizations.dogsAvailableForAdoption,
                          style: GoogleFonts.dancingScript(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder(
                          valueListenable: dogsBox.listenable(),
                          builder: (context, Box<Dog> box, _) {
                            print('UserProfilePage - ValueListenableBuilder triggered for Adoption Dogs');
                            final uniqueDogs = <String, Dog>{};
                            for (var dog in box.values) {
                              if (!uniqueDogs.containsKey(dog.id)) {
                                uniqueDogs[dog.id] = dog;
                              } else {
                                print('UserProfilePage - Duplicate dog found in Hive: ${dog.name}, ID: ${dog.id}, ownerId: ${dog.ownerId}');
                              }
                            }
                            final adoptionDogs = uniqueDogs.values.where((dog) => dog.isAvailableForAdoption).toList();
                            if (!_areDogsEqual(_cachedAdoptionDogs, adoptionDogs)) {
                              _cachedAdoptionDogs = List.from(adoptionDogs);
                              print('UserProfilePage - Updated cached adoption dogs: ${_cachedAdoptionDogs.length}');
                            }
                            if (_cachedAdoptionDogs.isEmpty) {
                              return Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noDogsAvailableForAdoption,
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                ),
                              );
                            }
                            return ListView.builder(
                              key: const ValueKey('adoption_dog_list'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cachedAdoptionDogs.length,
                              itemBuilder: (context, index) {
                                final dog = _cachedAdoptionDogs[index];
                                print(
                                    'UserProfilePage - Displaying adoption dog at index $index: Name=${dog.name}, ID=${dog.id}, Breed=${dog.breed}, OwnerId=${dog.ownerId}');
                                return DogCard(
                                  key: ValueKey(dog.id),
                                  dog: dog,
                                  allDogs: widget.dogsList,
                                  currentUserId: _currentUserId,
                                  favoriteDogs: widget.favoriteDogs,
                                  onToggleFavorite: widget.onToggleFavorite,
                                  onDogUpdated: dog.ownerId == _currentUserId
                                      ? (updatedDog) {
                                          final originalIndex = box.values.toList().indexOf(dog);
                                          if (originalIndex != -1) {
                                            _updateDogInHive(updatedDog, originalIndex);
                                          }
                                        }
                                      : null,
                                  selectedRequesterDogId: Provider.of<AppState>(context, listen: false).selectedRequesterDogId,
                                  onRequesterDogChanged: (value) {
                                    Provider.of<AppState>(context, listen: false).setSelectedRequesterDogId(value);
                                  },
                                  onAdopt: () {
                                    SchedulerBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(localizations.adoptionRequestSent(dog.name)),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  likers: appState.dogLikes[dog.id] ?? [],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: isOwnProfile
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddDogPage(
                          onDogAdded: widget.onDogAdded,
                          favoriteDogs: widget.favoriteDogs,
                          onToggleFavorite: widget.onToggleFavorite,
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.pink,
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  bool _areDogsEqual(List<Dog> list1, List<Dog> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].name != list2[i].name ||
          list1[i].ownerId != list2[i].ownerId ||
          list1[i].age != list2[i].age ||
          list1[i].breed != list2[i].breed ||
          list1[i].gender != list2[i].gender ||
          list1[i].healthStatus != list2[i].healthStatus ||
          list1[i].isNeutered != list2[i].isNeutered ||
          list1[i].description != list2[i].description ||
          list1[i].ownerGender != list2[i].ownerGender ||
          list1[i].isAvailableForAdoption != list2[i].isAvailableForAdoption) {
        return false;
      }
    }
    return true;
  }

  Future<ImageProvider?> _loadProfileImage() async {
    if (_userDogs.isNotEmpty && _userDogs[0].imagePaths.isNotEmpty) {
      final imagePath = _userDogs[0].imagePaths[0];
      if (imagePath.startsWith('assets/')) {
        return AssetImage(imagePath);
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          return FileImage(file);
        }
      }
    }
    return null;
  }
}