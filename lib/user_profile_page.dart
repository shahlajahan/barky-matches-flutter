
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'add_dog_page.dart';
import 'app_state.dart';
import 'dog.dart';
import 'dog_card.dart';
import 'globals.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/screens/dog_parks/saved_parks_page.dart';
import 'package:barky_matches_fixed/adoption_page.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/ui/adoption/adoption_inbox_page.dart';
import 'package:barky_matches_fixed/ui/business/business_register_page.dart';
import 'package:barky_matches_fixed/ui/admin/admin_approval_page.dart';
import 'package:barky_matches_fixed/utils/firestore_cleaner.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'ui/admin/pages/admin_hub_page.dart';
import 'package:barky_matches_fixed/ui/feedback/feedback_form_page.dart';
import 'package:barky_matches_fixed/welcome_page.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barky_matches_fixed/play_date_requests_page_new.dart';
import 'package:provider/provider.dart';
import 'play_date_requests_page_new.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/setting/privacy_settings_page.dart';
import 'package:barky_matches_fixed/ui/support/report_problem_page.dart';

// ────────────────────────────────────────────────
//  جدید — کامپوننت‌های استاندارد TYPE A
// ────────────────────────────────────────────────

class ProfileHeader extends StatelessWidget {
  final ImageProvider? image;
  final String username;
  final String email;
  final String phone;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap;   // ← جدید
  final String city;

  const ProfileHeader({
    super.key,
    required this.image,
    required this.username,
    required this.email,
    required this.phone,
    this.onEdit,
    this.onAvatarTap,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // ← مرکز کردن کل هدر
      children: [
        Center(   // ← مطمئن می‌شیم کل Stack وسط صفحه باشه
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: onAvatarTap, // ← tap روی آواتار → انتخاب عکس
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: image,
                    backgroundColor: Colors.white,
                    child: image == null
                        ? const Icon(Icons.person, size: 60, color: Colors.pink)
                        : null,
                  ),
                ),
              ),

              if (onEdit != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: onEdit, // ← tap روی آیکون ویرایش → باز کردن فرم
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,           // ← مثل EditDogOverlay
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
  username,
  style: const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Color(0xFF9E1B4F),
  ),
),

        const SizedBox(height: 8),

        Text(
          email,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Color(0xFF9E1B4F)
          ),
        ),

        const SizedBox(height: 6),

        Text(
          phone,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Color(0xFF9E1B4F)
          ),
        ),
        Text(
  city,
  style: GoogleFonts.poppins(
    fontSize: 14,
    color: const Color(0xFF9E1B4F),
  ),
),
      ],
    );
  }
}

class ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ProfileSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
  title,
  style: GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF9E1B4F),
  ),
),
        const SizedBox(height: 10),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
  color: const Color(0xFF9E1B4F),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ],
),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//               کلاس اصلی صفحه
// ────────────────────────────────────────────────

class UserProfilePage extends StatefulWidget {
  final List<Dog> dogs;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
  final String userId;

  const UserProfilePage({
    super.key,
    required this.dogs,
    required this.favoriteDogs,
    required this.onToggleFavorite,
    required this.userId,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // همان متغیرهای قبلی بدون تغییر
  bool _initialized = false;
  bool _disposed = false;
  Future<ImageProvider?>? _profileImageFuture;
  late AppState _appState;
  String _currentUserId = '';
  Box<Dog>? _dogsBox;
  List<Dog> _userDogs = [];
  List<Dog> _adoptionDogs = [];
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _profileImageFile;
final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  List<Dog> _cachedUserDogs = [];
  List<Dog> _cachedAdoptionDogs = [];

  @override
void initState() {
  super.initState();

  debugPrint('👤 UserProfilePage dogs received = ${widget.dogs.length}');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _initializeData(); // ✅ SAFE
  });

  _profileImageFuture = _loadProfileImage();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final appState = context.read<AppState>();
    if (appState.otherUserProfileId != null) {
      appState.clearOtherUserProfile();
    }
  });
}
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  Future<void> _initializeData() async {
    try {
      // Hive box ممکنه هنوز باز نشده باشه
      if (!Hive.isBoxOpen('dogsBox')) {
        debugPrint('UserProfilePage - dogsBox is not open yet!');
      }
      Box<Dog>? _dogsBox;


      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
  debugPrint('👤 Guest mode → skipping auth redirect');
  return;
}

      _currentUserId = user.uid;
      debugPrint('UserProfilePage - Current userId: $_currentUserId');
      debugPrint('UserProfilePage - Profile userId: ${widget.userId}');

      await _fixDogsWithNullOwnerId();
      if (!mounted) return;

      await _loadUserInfo();
      await _loadBusinessStatus();
      if (!mounted) return;

      
      if (!mounted) return;
    } catch (e) {
      debugPrint('UserProfilePage - initializeData ERROR: $e');
      // مهم: حتی اگر خطا شد، از loading خارج شو تا صفحه خالی نمونه
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile init error: $e')),
      );
    } finally {
  if (!mounted || _disposed) return;
  setState(() {
    _isLoading = false;
  });
}

  }

  Future<void> _loadBusinessStatus() async {
  try {

    final q = await FirebaseFirestore.instance
        .collection("businesses")
        .where("ownerUid", isEqualTo: _currentUserId)
        .limit(1)
        .get();

    final appState = context.read<AppState>();

    if (q.docs.isNotEmpty) {

      final doc = q.docs.first;

      appState.setApprovedBusiness(
        businessId: doc.id,
      );

      debugPrint("✅ business approved: ${doc.id}");

      return;
    }

    final pending = await FirebaseFirestore.instance
        .collection("business_requests")
        .where("uid", isEqualTo: _currentUserId)
        .limit(1)
        .get();

    if (pending.docs.isNotEmpty) {

      final status = pending.docs.first.data()['status'];

      appState.setBusinessStatus(status);

      debugPrint("⌛ business request status: $status");
    }

  } catch (e) {
    debugPrint("Business load error: $e");
  }
}

  Future<void> _pickProfileImage() async {
  try {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (file == null) return;

    if (!mounted) return;

    setState(() {
      _profileImageFile = File(file.path);
    });

    // بعداً می‌تونی اینجا آپلود به Firebase Storage اضافه کنی
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("خطا در انتخاب عکس: $e")),
    );
  }
}

  Future<void> _fixDogsWithNullOwnerId() async {
    try {
      final box = _dogsBox;
      if (box == null) return;

      final dogsToFix = box.values
          .where((dog) =>
              (dog.ownerId == null || dog.ownerId!.isEmpty) &&
              dog.isOwner == true)
          .toList();
          if (dogsToFix.isEmpty) return;


      for (var dog in dogsToFix) {
        final updatedDog = dog.copy(ownerId: _currentUserId);
        
        await box.put(dog.id, updatedDog);

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
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('UserProfilePage - fixDogs error: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    debugPrint('UserProfilePage - Loading user info for userId: ${widget.userId}');

    try {
      // ✅ پاکسازی کلیدهای lowercase قدیمی
      final lowerCaseUserId = widget.userId.toLowerCase();
      if (lowerCaseUserId != widget.userId &&
          userDataBox.containsKey(lowerCaseUserId)) {
        await userDataBox.delete(lowerCaseUserId);
      }

      // 1) Hive cache
      final cachedData = userDataBox.get(widget.userId);
      if (cachedData != null && mounted) {
        final savedParks = List<String>.from(cachedData['savedParks'] ?? []);
        

        setState(() {
          final loc = AppLocalizations.of(context)!;
          _usernameController.text = cachedData['username'] ?? loc.unknownUser;
          _emailController.text = cachedData['email'] ?? '';
          final phone = (cachedData['phone'] ?? '').toString();
          _phoneController.text = phone.isEmpty ? loc.notProvided : phone;
        });
      }

      // 2) Firestore
      final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(widget.userId)
    .get();

if (userDoc.exists) {
  final rawData = userDoc.data() ?? {};

  // ✅ FIX اصلی: تبدیل Timestamp
  if (userDoc.exists) {
  final rawData = userDoc.data() ?? {};

  final cleaned = cleanDeep(
    Map<String, dynamic>.from(rawData),
  );

  await userDataBox.put(widget.userId, cleaned);

  if (!mounted || _disposed) return;

  setState(() {
    final loc = AppLocalizations.of(context)!;

    _usernameController.text =
        cleaned['username'] ?? loc.unknownUser;

    _emailController.text =
        cleaned['email'] ?? '';

    _phoneController.text =
        (cleaned['phone'] ?? '').toString().isEmpty
            ? loc.notProvided
            : cleaned['phone'].toString();
  });
}
}


     
    } on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    debugPrint('UserProfilePage - Firestore denied, using cache only');
    return; // ⛔️ retry نکن
  }
  debugPrint('UserProfilePage - Firebase error: $e');
} catch (e) {
  debugPrint('UserProfilePage - Error loading user info: $e');
}

  }

  
  

  Future<void> _saveDogToHive(Map<String, dynamic> data) async {
    final box = _dogsBox ?? Hive.box<Dog>('dogsBox');
    final dog = data['dog'] as Dog;

    await box.put(dog.id, dog);
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
    }, SetOptions(merge: true));
  }

  void _updateDogInHive(Dog updatedDog, int originalIndex) {
    _saveDogToHive({'dog': updatedDog, 'index': originalIndex}).then((_) {
      
    }).catchError((e) {
      debugPrint('UserProfilePage - Error updating dog in Hive: $e');
    });
  }

  void _updateUserInfo() async {
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newUsername.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.usernameCannotBeEmpty)),
      );
      return;
    }

    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    final userData = {
      'username': newUsername,
      'email': newEmail,
      'phone': newPhone.isEmpty
          ? AppLocalizations.of(context)!.notProvided
          : newPhone,
      'password': userDataBox.get(_currentUserId)?['password'] ?? '',
      'isPremium': newEmail == 'durbinistanbul@gmail.com' ? true : false,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .set(userData, SetOptions(merge: true));

      userDataBox.put(_currentUserId, userData);

      if (!mounted || _disposed) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.profileUpdatedSuccessfully),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('UserProfilePage - Error updating user info: $e');
      if (!mounted || _disposed) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUserInfo(e.toString()))),
      );
    }
  }

  void _editProfile() {
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) {
      return EditProfileOverlay(
        userId: _currentUserId,
        usernameController: _usernameController,
        emailController: _emailController,
        phoneController: _phoneController,
        onClose: () {
          Navigator.pop(context);
        },
        onSaved: () {
          if (!mounted) return;
          setState(() {});
        },
      );
    },
  );
}

ImageProvider? _getProfileHeaderImage() {
  if (_profileImageFile != null) {
    return FileImage(_profileImageFile!);
  }

  final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
  final cached = userDataBox.get(_currentUserId);
  final photoUrl = (cached?['photoUrl'] ?? '').toString().trim();

  if (photoUrl.isNotEmpty) {
    return NetworkImage(photoUrl);
  }

  return null;
}

  void _logout() async {
    try {
      await AuthTrap.signOut(reason: 'PUT_REASON_HERE');
      Hive.box<Dog>('dogsBox').clear();
      Hive.box<Map<dynamic, dynamic>>('userDataBox').clear();
      

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const WelcomePage()),
  (route) => false,
);
    } catch (e) {
      debugPrint('UserProfilePage - logout error: $e');
    }
  }


@override
void dispose() {
  _disposed = true;

  _usernameController.dispose();
  _emailController.dispose();
  _phoneController.dispose();

  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    if (_currentUserId == 'guest') {
    return const Center(
      child: Text(
        "Guest cannot access profile",
        style: TextStyle(color: Colors.black),
      ),
    );
  }
    final appState = context.watch<AppState>();
    final userDogs = widget.dogs;
    final loc = AppLocalizations.of(context)!;
    final isOwnProfile = _currentUserId == widget.userId;

    // Sub-pages (بدون تغییر)
    if (appState.profileSubPage == ProfileSubPage.savedParks) {
      return const SavedParksPage();
    }
    if (appState.profileSubPage == ProfileSubPage.adoptionInbox) {
      return AdoptionInboxPage();
    }
    if (appState.profileSubPage == ProfileSubPage.businessRegister) {
      return const BusinessRegisterPage();
    }
    if (appState.profileSubPage == ProfileSubPage.businessDashboard) {
      return WillPopScope(
        onWillPop: () async {
          context.read<AppState>().closeProfileSubPage();
          return false;
        },
        child: _CenterDashboard(appState.businessId!),
      );
    }
    if (appState.profileSubPage == ProfileSubPage.businessStatus) {
      return WillPopScope(
        onWillPop: () async {
          context.read<AppState>().closeProfileSubPage();
          return false;
        },
        child: _BusinessStatusPage(),
      );
    }

    if (_isLoading || _currentUserId.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

   return SafeArea(
  top: false,
  child: Container(
    color: const Color(0xFFF5F5F5), // همان background روشن Home
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. هدر جدید
              ProfileHeader(
  image: _getProfileHeaderImage(),
  username: _usernameController.text,
  email: _emailController.text,
  phone: _phoneController.text,
  city: "Istanbul",
  onEdit: isOwnProfile ? _editProfile : null,
  onAvatarTap: isOwnProfile ? _editProfile : null,
),

              const SizedBox(height: 32),

              // 2. Activity
              ProfileSection(
                title: "Activity",
                children: [
                  ProfileTile(
                    icon: Icons.bookmark,
                    title: "Saved Parks",
                    onTap: () => context.read<AppState>().openSavedParks(),
                  ),
                 ProfileTile(
  icon: Icons.favorite,
  title: "Matches",
  onTap: () {
    context.read<AppState>().setCurrentTab(NavTab.playdate);
  },
),
                  ProfileTile(
                    icon: Icons.pets,
                    title: "Adoption Requests",
                    onTap: () => context.read<AppState>().openAdoptionInbox(),
                  ),
                  
                ],
              ),

              // 3. Business Section (logic اصلی حفظ شده)
              ProfileSection(
                title: "Business",
                children: [
                  if (appState.hasApprovedBusiness)
                    _ApprovedBusinessCard()
                  else if (appState.hasPendingBusiness)
                    _WaitingForApprovalCard()
                  else if (appState.businessStatus == 'rejected')
                    _RejectedBusinessCard()
                  else
                    _RegisterBusinessButton(),
                ],
              ),
if (appState.isAdmin)
  ProfileSection(
    title: "Admin",
    children: [
      _AdminPanelCard(),
    ],
  ),
              // 4. Support (Feedback اضافه شد)
              ProfileSection(
                title: "Support",
                children: [
                  ProfileTile(
                    icon: Icons.feedback,
                    title: "Send Feedback",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedbackFormPage(),
                        ),
                      );
                    },
                  ),
                  ProfileTile(
                    icon: Icons.help,
                    title: "Help Center",
                    onTap: () {
                      // بعداً می‌تونی صفحه کمک اضافه کنی
                    },
                  ),
                  
                  ProfileTile(
  icon: Icons.privacy_tip,
  title: "Privacy",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacySettingsPage(),
      ),
    );
  },
),

                  ProfileTile(
  icon: Icons.bug_report,
  title: "Report Problem",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportProblemPage(),
      ),
    );
  },
),

                ],
              ),

              // 5. Settings (Language + Theme + Logout)
              if (isOwnProfile)
                ProfileSection(
                  title: "Settings",
                  children: [
                    ProfileTile(
                      icon: Icons.language,
                      title: "Language",
                      onTap: () {
  _showLanguageSelector(context);
},
                    ),
                    ProfileTile(
                      icon: Icons.dark_mode,
                      title: "Theme",
                      onTap: () {
                        // بعداً پیاده‌سازی
                      },
                    ),
                    ProfileTile(
                      icon: Icons.logout,
                      title: "Logout",
                      onTap: _logout,
                    ),
                  ],
                ),

              // 6. My Dogs (بدون تغییر در محتوا)
              ProfileSection(
                title: loc.myDogs,
                children: [
                  if (isOwnProfile)
  ProfileTile(
    icon: Icons.add,
    title: "Add Dog",
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddDogPage(
            onDogAdded: (newDog) {
              final appState = context.read<AppState>();
              appState.setMyDogs([...appState.myDogs, newDog]);
            },
            favoriteDogs: widget.favoriteDogs,
            onToggleFavorite: widget.onToggleFavorite,
          ),
        ),
      );
    },
  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: userDogs.length,
                    itemBuilder: (context, index) {
                      final dog = userDogs[index];
                      return DogCard(
                        dog: dog,
                        allDogs: appState.allDogs,
                        currentUserId: _currentUserId,
                        favoriteDogs: widget.favoriteDogs,
                        onToggleFavorite: widget.onToggleFavorite,
                        enablePlaydate: false,
                        onAdopt: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdoptionPage(
                                dogs: appState.allDogs,
                                favoriteDogs: appState.favoriteDogs,
                                onToggleFavorite: (dog) {
                                  appState.toggleFavorite(dog);
                                },
                              ),
                            ),
                          );
                        },
                        onDogUpdated: isOwnProfile
                            ? (updatedDog) {
                                final updated = userDogs
                                    .map((d) => d.id == updatedDog.id ? updatedDog : d)
                                    .toList();
                                context.read<AppState>().setMyDogs(updated);
                              }
                            : null,
                        likers: appState.dogLikes[dog.id] ?? [],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 80), // فضای پایین برای FAB
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          ListTile(
            title: const Text("English"),
            onTap: () {
              context.read<AppState>().setLocale('en');
              Navigator.pop(context);
            },
          ),

          ListTile(
            title: const Text("فارسی"),
            onTap: () {
              context.read<AppState>().setLocale('fa');
              Navigator.pop(context);
            },
          ),

          ListTile(
            title: const Text("Türkçe"),
            onTap: () {
              context.read<AppState>().setLocale('tr');
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

  Future<ImageProvider?> _loadProfileImage() async {
  if (!mounted) return null;

  final myDogs = context.read<AppState>().myDogs;


  if (myDogs.isEmpty) return null;

  final dog = myDogs.first;
  if (dog.imagePaths.isEmpty) return null;

  final imagePath = dog.imagePaths.first;
  if (imagePath.startsWith('assets/')) return AssetImage(imagePath);

  final file = File(imagePath);
  if (await file.exists()) return FileImage(file);

  return null;
}

}

class _CenterDashboard extends StatefulWidget {
  final String centerId;
  const _CenterDashboard(this.centerId);

  @override
  State<_CenterDashboard> createState() => _CenterDashboardState();
}

class _CenterDashboardState extends State<_CenterDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.pink[400],
        title: const Text("Manage Adoption Center"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<AppState>().closeProfileSubPage();
          },
        ),
      ),
      body: Row(
        children: [

          /// 🔴 LEFT SIDEBAR
          Container(
            width: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),

                _buildMenuItem("Overview", 0),
                _buildMenuItem("Dogs", 1),
                _buildMenuItem("Requests", 2),
                _buildMenuItem("Settings", 3),
              ],
            ),
          ),

          /// ⚪ RIGHT CONTENT
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, int index) {
    final selected = _selectedIndex == index;

    return ListTile(
      selected: selected,
      selectedTileColor: Colors.white24,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const Text("Overview Section");
      case 1:
        return const Text("Dogs Section");
      case 2:
        return const Text("Requests Section");
      case 3:
        return const Text("Settings Section");
      default:
        return const SizedBox();
    }
  }
}
class _WaitingForApprovalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC107),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Application Under Review",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("Your adoption center request is pending approval.",
              style: GoogleFonts.poppins(color: Colors.white)),
        ],
      ),
    );
  }
}

class _RegisterBusinessButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<AppState>().openBusinessRegister();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
  color: const Color(0xFF9E1B4F),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ],
),
        child: Row(
          children: [
            const Icon(Icons.store, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Register Adoption Center',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _AdminPanelCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>  AdminHubPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFC62828),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Admin Panel",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ApprovedBusinessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return GestureDetector(
      onTap: () {
  final appState = context.read<AppState>();
  debugPrint("👉 OPEN DASHBOARD with businessId = ${appState.businessId}");
  appState.openProfileSubPage(ProfileSubPage.businessDashboard);
},
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Manage Business Center",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _RejectedBusinessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Application Rejected",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (appState.initialBusinessResolutionReason != null)
            Text(
              "Reason: ${appState.initialBusinessResolutionReason}",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              appState.openBusinessRegister();
            },
            child: Text(
              "Re-Apply",
              style: GoogleFonts.poppins(
                color: Colors.white,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _BusinessStatusPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink[400],
        title: const Text("Business Status"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            appState.businessStatus ?? 'Unknown',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class EditProfileOverlay extends StatefulWidget {
  final String userId;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String? initialPhotoUrl;
  final VoidCallback onClose;
  final VoidCallback? onSaved;

  const EditProfileOverlay({
    super.key,
    required this.userId,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.onClose,
    this.initialPhotoUrl,
    this.onSaved,
  });

  @override
  State<EditProfileOverlay> createState() => _EditProfileOverlayState();
}

class _EditProfileOverlayState extends State<EditProfileOverlay> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _bioController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingImage = false;

  File? _selectedImageFile;
  String? _photoUrl;

  String? _usernameError;
  String? _emailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
    _loadExistingExtraFields();
  }

  Future<void> _loadExistingExtraFields() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      _bioController.text = (data['bio'] ?? '').toString();

      final existingPhoto = (data['photoUrl'] ?? '').toString().trim();
      if ((_photoUrl == null || _photoUrl!.isEmpty) && existingPhoto.isNotEmpty) {
        setState(() {
          _photoUrl = existingPhoto;
        });
      }
    } catch (e) {
      debugPrint('EditProfileOverlay - load existing extra fields error: $e');
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (_selectedImageFile != null || (_photoUrl?.isNotEmpty ?? false))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) return;

    if (source == 'remove') {
      setState(() {
        _selectedImageFile = null;
        _photoUrl = '';
      });
      return;
    }

    final imageSource =
        source == 'camera' ? ImageSource.camera : ImageSource.gallery;

    try {
      final XFile? file = await _picker.pickImage(
        source: imageSource,
        imageQuality: 85,
        maxWidth: 1400,
      );

      if (file == null || !mounted) return;

      setState(() {
        _selectedImageFile = File(file.path);
      });
    } catch (e) {
      debugPrint('EditProfileOverlay - pick image error: $e');
      if (!mounted) return;
      _showSnack('Image selection failed.');
    }
  }

  Future<String> _uploadProfileImage(File file) async {
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(widget.userId)
        .child('profile')
        .child(fileName);

    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  bool _validate() {
    final username = widget.usernameController.text.trim();
    final email = widget.emailController.text.trim();
    final phone = widget.phoneController.text.trim();

    String? usernameError;
    String? emailError;
    String? phoneError;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final phoneRegex = RegExp(r'^[0-9+\s()-]*$');

    if (username.isEmpty) {
      usernameError = 'Username cannot be empty';
    } else if (username.length < 3) {
      usernameError = 'Username must be at least 3 characters';
    } else if (username.length > 20) {
      usernameError = 'Username must be at most 20 characters';
    } else if (username.contains(' ')) {
      usernameError = 'Username cannot contain spaces';
    }

    if (email.isEmpty) {
      emailError = 'Email cannot be empty';
    } else if (!emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email';
    }

    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      phoneError = 'Phone contains invalid characters';
    }

    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _phoneError = phoneError;
    });

    return usernameError == null && emailError == null && phoneError == null;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _isUploadingImage) return;

    FocusScope.of(context).unfocus();

    final isValid = _validate();
    if (!isValid) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String finalPhotoUrl = _photoUrl?.trim() ?? '';

      if (_selectedImageFile != null) {
        setState(() {
          _isUploadingImage = true;
        });

        finalPhotoUrl = await _uploadProfileImage(_selectedImageFile!);

        if (!mounted) return;

        setState(() {
          _isUploadingImage = false;
          _photoUrl = finalPhotoUrl;
        });
      }

      final username = widget.usernameController.text.trim();
      final email = widget.emailController.text.trim();
      final phone = widget.phoneController.text.trim();
      final bio = _bioController.text.trim();

      final userData = <String, dynamic>{
        'username': username,
        'email': email,
        'phone': phone,
        'bio': bio,
        'photoUrl': finalPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(userData, SetOptions(merge: true));

      final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
      final oldData = Map<String, dynamic>.from(
        userDataBox.get(widget.userId)?.cast<String, dynamic>() ?? {},
      );

      final merged = {
        ...oldData,
        'username': username,
        'email': email,
        'phone': phone,
        'bio': bio,
        'photoUrl': finalPhotoUrl,
      };

      await userDataBox.put(widget.userId, merged);

      if (!mounted) return;

      _showSnack('Profile updated successfully.');

      widget.onSaved?.call();
      widget.onClose();
    } catch (e) {
      debugPrint('EditProfileOverlay - save profile error: $e');
      if (!mounted) return;
      _showSnack('Failed to update profile.');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isUploadingImage = false;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _whiteDecoration({
    String? hintText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF9E1B4F),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _whiteField(
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 15,
      ),
      decoration: _whiteDecoration(
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatarChild;

    if (_selectedImageFile != null) {
      avatarChild = ClipOval(
        child: Image.file(
          _selectedImageFile!,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
        ),
      );
    } else if ((_photoUrl ?? '').isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          _photoUrl!,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    } else {
      avatarChild = _fallbackAvatar();
    }

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: avatarChild,
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: _isUploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 110,
      height: 110,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white24,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 52,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () {
    FocusScope.of(context).unfocus();
  },
  child: Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black54),
        ),
      ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ScrollConfiguration(
                behavior: _ProfileOverlayScrollBehavior(),
                child: SingleChildScrollView(
  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n?.editProfile ?? 'Edit Profile',
                          style: GoogleFonts.dancingScript(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),

                        _buildAvatar(),
                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: _isSaving || _isUploadingImage
                              ? null
                              : _showImageSourceSheet,
                          child: Text(
                            'Change Photo',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n?.username ?? 'Username',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _whiteField(
                          widget.usernameController,
                          hintText: 'Enter username',
                          errorText: _usernameError,
                        ),

                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n?.email ?? 'Email',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _whiteField(
                          widget.emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'Enter email',
                          errorText: _emailError,
                        ),

                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n?.phoneNumber ?? 'Phone',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _whiteField(
                          widget.phoneController,
                          keyboardType: TextInputType.phone,
                          hintText: 'Optional phone number',
                          errorText: _phoneError,
                        ),

                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Bio',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _whiteField(
                          _bioController,
                          maxLines: 4,
                          hintText: 'Tell people a little about yourself',
                        ),

                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : widget.onClose,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  l10n?.cancel ?? 'Cancel',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF9E1B4F),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        l10n?.save ?? 'Save',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
              ),
            ),
          ),
        ),
      ],
  ),
    );
  }
}

class _ProfileOverlayScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}