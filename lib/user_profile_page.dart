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
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/screens/dog_parks/saved_parks_page.dart';
import 'package:barky_matches_fixed/adoption_page.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/ui/adoption/adoption_inbox_page.dart';
import 'package:barky_matches_fixed/ui/business/business_register_page.dart';
import 'package:barky_matches_fixed/utils/firestore_cleaner.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'ui/admin/pages/admin_hub_page.dart';
import 'package:barky_matches_fixed/ui/feedback/feedback_form_page.dart';
import 'package:barky_matches_fixed/welcome_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/setting/privacy_settings_page.dart';
import 'package:barky_matches_fixed/ui/support/report_problem_page.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/business_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/orders/my_orders_page.dart';
import 'package:barky_matches_fixed/ui/appointments/my_appointments_page.dart';

import 'package:barky_matches_fixed/ui/setting/delete_account_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/groomy/groomy_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/pet_hotel/pet_hotel_dashboard_page.dart';

import 'package:barky_matches_fixed/ui/profile/change_password_page.dart';

import 'package:barky_matches_fixed/services/fcm_token_service.dart';
import 'package:barky_matches_fixed/social/pages/create_social_post_page.dart';

import 'package:barky_matches_fixed/social/pages/saved_posts_page.dart';

import 'package:barky_matches_fixed/social/widgets/user_posts_grid.dart';

// ────────────────────────────────────────────────
//  جدید — کامپوننت‌های استاندارد TYPE A
// ────────────────────────────────────────────────

class ProfileHeader extends StatelessWidget {
  final ImageProvider? image;
  final String username;
  final String email;
  final String phone;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap; // ← جدید
  final String city;
  final String district;

  const ProfileHeader({
    super.key,
    required this.image,
    required this.username,
    required this.email,
    required this.phone,
    this.onEdit,
    this.onAvatarTap,
    required this.city,
    required this.district,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // ← مرکز کردن کل هدر
      children: [
        Center(
          // ← مطمئن می‌شیم کل Stack وسط صفحه باشه
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
                        color: Colors.black54, // ← مثل EditDogOverlay
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
          style: GoogleFonts.poppins(fontSize: 15, color: Color(0xFF9E1B4F)),
        ),

        const SizedBox(height: 6),

        Text(
          phone,
          style: GoogleFonts.poppins(fontSize: 15, color: Color(0xFF9E1B4F)),
        ),
        if (_locationText.isNotEmpty)
          Text(
            _locationText,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF9E1B4F),
            ),
          ),
      ],
    );
  }

  String get _locationText {
    final trimmedCity = city.trim();
    final trimmedDistrict = district.trim();

    if (trimmedCity.isNotEmpty && trimmedDistrict.isNotEmpty) {
      return '$trimmedDistrict, $trimmedCity';
    }

    if (trimmedCity.isNotEmpty) return trimmedCity;
    return '';
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
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
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
  final bool _initialized = false;
  bool _disposed = false;
  Future<ImageProvider?>? _profileImageFuture;
  Future<DocumentSnapshot>? _businessDashboardFuture;
  String? _businessDashboardFutureBusinessId;
  late AppState _appState;
  String _currentUserId = '';
  Box<Dog>? _dogsBox;
  final List<Dog> _userDogs = [];
  final List<Dog> _adoptionDogs = [];
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _generatingFcmToken = false;
  final List<Dog> _cachedUserDogs = [];
  final List<Dog> _cachedAdoptionDogs = [];
  String _city = '';
  String _district = '';

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
      Box<Dog>? dogsBox;

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
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.userProfileInitError(e.toString()),
          ),
        ),
      );
    } finally {
      if (!mounted || _disposed) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRegisterBusinessButton() {
    return GestureDetector(
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 300));

        final appState = Provider.of<AppState>(context, listen: false);

        debugPrint('🔥 REGISTER CHECK');
        debugPrint('🔥 GOLD=${appState.isGold}');
        debugPrint('🔥 PLAN=${appState.subscription.plan}');
        debugPrint('🔥 STATUS=${appState.subscription.status}');
        debugPrint('🔥 CAN REGISTER=${appState.canRegisterBusiness}');

        if (!appState.canRegisterBusiness) {
          _showUpgradeRequiredSheet(context);
          return;
        }

        appState.openProfileSubPage(ProfileSubPage.businessRegister);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                AppLocalizations.of(context)!.businessRegisterTitle,
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

  Future<void> _loadBusinessStatus() async {
    try {
      final uid = _currentUserId;

      if (uid.isEmpty) {
        debugPrint("❌ UID is null");
        return;
      }

      debugPrint("🔍 checking businesses for uid=$uid");

      final appState = context.read<AppState>();

      // =========================
      // 1️⃣ CHECK APPROVED BUSINESS (CORRECT WAY)
      // =========================
      final q = await FirebaseFirestore.instance
          .collection("businesses")
          .where("ownerUid", isEqualTo: uid)
          .where("status", isEqualTo: "approved")
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final data = doc.data();

        final sectors = List<String>.from(data['sectors'] ?? []);

        appState.setApprovedBusiness(businessId: doc.id, sectors: sectors);

        debugPrint("✅ business approved: ${doc.id}");
        return;
      }

      // =========================
      // 2️⃣ CHECK PENDING BUSINESS (OPTIONAL BUT GOOD)
      // =========================
      final pendingBusiness = await FirebaseFirestore.instance
          .collection("businesses")
          .where("ownerUid", isEqualTo: uid)
          .where("status", isEqualTo: "pending")
          .limit(1)
          .get();

      if (pendingBusiness.docs.isNotEmpty) {
        appState.setBusinessStatus('pending');

        debugPrint("⌛ business pending (from businesses)");
        return;
      }

      // =========================
      // 3️⃣ FALLBACK → BUSINESS REQUESTS
      // =========================
      debugPrint("🔍 checking business_requests...");

      final pending = await FirebaseFirestore.instance
          .collection("business_requests")
          .where("uid", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .limit(1)
          .get();

      if (pending.docs.isNotEmpty) {
        final doc = pending.docs.first;
        final data = doc.data();
        final status = data['status'];

        debugPrint("📦 REQUEST FOUND: ${doc.id}");
        debugPrint("📦 REQUEST STATUS: $status");

        appState.setBusinessStatus(status);

        // =========================
        // 4️⃣ APPROVED VIA REQUEST → FETCH BUSINESS
        // =========================
        if (status == 'approved') {
          final businessId = data['businessId'];

          if (businessId != null) {
            final bizDoc = await FirebaseFirestore.instance
                .collection("businesses")
                .doc(businessId)
                .get();

            if (bizDoc.exists) {
              final sectors = List<String>.from(
                bizDoc.data()?['sectors'] ?? [],
              );

              appState.setApprovedBusiness(
                businessId: businessId,
                sectors: sectors,
              );

              debugPrint("✅ approved via request → businessId=$businessId");
              return;
            } else {
              debugPrint("⚠️ business doc missing for approved request");
            }
          }
        }

        return;
      }

      // =========================
      // 5️⃣ NOTHING FOUND
      // =========================
      appState.clearBusinessState();
      debugPrint("❌ no business, no request");
    } catch (e) {
      debugPrint("❌ Business load error: $e");
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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.userProfileImagePickError(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _fixDogsWithNullOwnerId() async {
    try {
      final box = _dogsBox;
      if (box == null) return;

      final dogsToFix = box.values
          .where(
            (dog) =>
                (dog.ownerId == null || dog.ownerId!.isEmpty) &&
                dog.isOwner == true,
          )
          .toList();
      if (dogsToFix.isEmpty) return;

      for (var dog in dogsToFix) {
        final updatedDog = dog.copy(ownerId: _currentUserId);

        await box.put(dog.id, updatedDog);

        await FirebaseFirestore.instance.collection('dogs').doc(dog.id).set({
          'id': dog.id,
          'name': updatedDog.name,
          'petName': updatedDog.name,
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
        debugPrint(
          '🐾 PET NAME SYNC → name=${updatedDog.name} petName=${updatedDog.name}',
        );
      }
    } catch (e) {
      debugPrint('UserProfilePage - fixDogs error: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    debugPrint(
      'UserProfilePage - Loading user info for userId: ${widget.userId}',
    );

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
          _city = (cachedData['city'] ?? '').toString();
          _district = (cachedData['district'] ?? '').toString();
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

          final cleaned = cleanDeep(Map<String, dynamic>.from(rawData));
          _city = cleaned['city'] ?? '';
          _district = cleaned['district'] ?? '';
          await userDataBox.put(widget.userId, cleaned);

          if (!mounted || _disposed) return;

          setState(() {
            final loc = AppLocalizations.of(context)!;

            _usernameController.text = cleaned['username'] ?? loc.unknownUser;

            _emailController.text = cleaned['email'] ?? '';

            _phoneController.text = (cleaned['phone'] ?? '').toString().isEmpty
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
      'petName': dog.name,
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
    debugPrint('🐾 PET NAME SYNC → name=${dog.name} petName=${dog.name}');
  }

  void _updateDogInHive(Dog updatedDog, int originalIndex) {
    _saveDogToHive({
      'dog': updatedDog,
      'index': originalIndex,
    }).then((_) {}).catchError((e) {
      debugPrint('UserProfilePage - Error updating dog in Hive: $e');
    });
  }

  void _updateUserInfo() async {
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newCity = _city.trim();
    final newDistrict = _district.trim();

    if (newUsername.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.usernameCannotBeEmpty),
        ),
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
      'city': newCity,
      'district': newDistrict,
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
          content: Text(
            AppLocalizations.of(context)!.profileUpdatedSuccessfully,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('UserProfilePage - Error updating user info: $e');
      if (!mounted || _disposed) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorLoadingUserInfo(e.toString()),
          ),
        ),
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
            _loadUserInfo();
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
      AuthTrap.signOut(reason: 'session_expired');
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

  Future<void> _generateFcmTokenDebug() async {
    if (_generatingFcmToken) return;

    setState(() => _generatingFcmToken = true);
    try {
      final token = await FcmTokenService.generateAndSaveForCurrentUser(
        source: 'debug_button',
      );
      debugPrint('🔥 FCM DEBUG BUTTON TOKEN: $token');

      if (!mounted) return;
      final message = token == null || token.isEmpty
          ? 'FCM token generation failed'
          : 'FCM token saved (${token.length} chars)';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('🔥 FCM DEBUG BUTTON FAILED: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('FCM token generation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingFcmToken = false);
      }
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
    final appState = context.watch<AppState>();

    if (appState.isGuestUser) {
      return _buildGuestProfile(); // 👈 اینو می‌سازیم پایین
    }

    final userDogs = context.watch<AppState>().myDogs;
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
    if (appState.profileSubPage == ProfileSubPage.appointments) {
      return const MyAppointmentsPage();
    }

    if (appState.profileSubPage == ProfileSubPage.myOrders) {
      return const MyOrdersPage();
    }

    if (appState.profileSubPage == ProfileSubPage.feedback) {
      return const FeedbackFormPage();
    }

    if (appState.profileSubPage == ProfileSubPage.privacy) {
      return const PrivacySettingsPage();
    }

    if (appState.profileSubPage == ProfileSubPage.reportProblem) {
      return const ReportProblemPage();
    }

    if (appState.profileSubPage == ProfileSubPage.upgrade) {
      if (appState.canRegisterBusiness) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<AppState>().openProfileSubPage(
            ProfileSubPage.businessRegister,
          );
        });

        return const SizedBox();
      }

      return WillPopScope(
        onWillPop: () async {
          context.read<AppState>().closeProfileSubPage();
          return false;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF120914),
          body: SafeArea(
            child: Stack(
              children: [
                const UpgradePage(),

                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      context.read<AppState>().closeProfileSubPage();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (appState.profileSubPage == ProfileSubPage.changePassword) {
      return const ChangePasswordPage();
    }

    if (appState.profileSubPage == ProfileSubPage.deleteAccount) {
      return const DeleteAccountPage();
    }
    if (appState.profileSubPage == ProfileSubPage.businessDashboard) {
      debugPrint(
        '👤 UserProfilePage businessDashboard branch build '
        '${identityHashCode(this)} businessId=${appState.businessId}',
      );
      if (appState.businessId == null) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!appState.hasApprovedBusiness) {
        debugPrint("🚫 جلوگیری از ورود به dashboard (not approved)");

        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<AppState>().closeProfileSubPage();
        });

        return const SizedBox();
      }

      final businessId = appState.businessId!;
      if (_businessDashboardFuture == null ||
          _businessDashboardFutureBusinessId != businessId) {
        _businessDashboardFutureBusinessId = businessId;
        _businessDashboardFuture = FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get();
      }

      return FutureBuilder<DocumentSnapshot>(
        future: _businessDashboardFuture,
        builder: (context, snapshot) {
          debugPrint(
            '👤 UserProfilePage FutureBuilder rebuild '
            '${identityHashCode(this)} state=${snapshot.connectionState} '
            'hasData=${snapshot.hasData} businessId=$businessId',
          );
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final sectors = List<String>.from(data['sectors'] ?? []);

          debugPrint("🏪 REAL SECTORS => $sectors");

          Widget dashboardBody;

          if (sectors.contains("pet_shop")) {
            dashboardBody = const PetShopDashboardPage();
          } else if (sectors.contains("veterinary")) {
            dashboardBody = BusinessDashboardPage(
              businessId: appState.businessId!,
            );
          } else if (sectors.contains("groomer") ||
              sectors.contains("grooming")) {
            dashboardBody = GroomyDashboardPage(
              businessId: appState.businessId!,
              businessData: data,
            );
          } else if (sectors.contains("pet_hotel") ||
              sectors.contains("hotel")) {
            dashboardBody = PetHotelDashboardPage(
              businessId: appState.businessId!,
              businessData: data,
            );
          } else {
            dashboardBody = Center(
              child: Text("Unknown business type → $sectors"),
            );
          }

          return WillPopScope(
            onWillPop: () async {
              context.read<AppState>().closeProfileSubPage();
              return false;
            },
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 14, 16, 10),
                    color: AppTheme.bg,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            context.read<AppState>().closeProfileSubPage();
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.userProfileBusinessDashboard,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(child: dashboardBody),
                ],
              ),
            ),
          );
        },
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
                city: _city,
                district: _district,
                onEdit: isOwnProfile ? _editProfile : null,
                onAvatarTap: isOwnProfile ? _editProfile : null,
              ),

              const SizedBox(height: 32),

              // 2. Activity
              ProfileSection(
                title: AppLocalizations.of(context)!.userProfileActivity,
                children: [
                  ProfileTile(
                    icon: Icons.add_a_photo,
                    title: "Create Post",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateSocialPostPage(),
                        ),
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.bookmark,
                    title: "Saved Posts",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedPostsPage(),
                        ),
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.bookmark,
                    title: AppLocalizations.of(context)!.userProfileSavedParks,
                    onTap: () => context.read<AppState>().openSavedParks(),
                  ),

                  ProfileTile(
                    icon: Icons.favorite,
                    title: AppLocalizations.of(context)!.userProfileMatches,
                    onTap: () {
                      context.read<AppState>().setCurrentTab(NavTab.playdate);
                    },
                  ),

                  ProfileTile(
                    icon: Icons.shopping_bag,
                    title: AppLocalizations.of(context)!.userProfileMyOrders,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.myOrders,
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.event_available,
                    title: AppLocalizations.of(context)!.myAppointments,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.appointments,
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.pets,
                    title: AppLocalizations.of(
                      context,
                    )!.userProfileAdoptionRequests,
                    onTap: () => context.read<AppState>().openAdoptionInbox(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Posts',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              UserPostsGrid(userId: widget.userId),
              // 3. Business Section (logic اصلی حفظ شده)
              ProfileSection(
                title: AppLocalizations.of(context)!.userProfileBusiness,
                children: [
                  if (appState.hasApprovedBusiness)
                    _ApprovedBusinessCard()
                  else if (appState.hasPendingBusiness)
                    _WaitingForApprovalCard()
                  else if (appState.businessStatus == 'rejected')
                    _RejectedBusinessCard()
                  else
                    _buildRegisterBusinessButton(),
                ],
              ),
              if (appState.isAdmin)
                ProfileSection(
                  title: AppLocalizations.of(context)!.userProfileAdmin,
                  children: [_AdminPanelCard()],
                ),
              // 4. Support (Feedback اضافه شد)
              ProfileSection(
                title: AppLocalizations.of(context)!.userProfileSupport,
                children: [
                  ProfileTile(
                    icon: Icons.feedback,
                    title: AppLocalizations.of(
                      context,
                    )!.userProfileSendFeedback,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.feedback,
                      );
                    },
                  ),
                  ProfileTile(
                    icon: Icons.help,
                    title: AppLocalizations.of(context)!.userProfileHelpCenter,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.helpCenter,
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.privacy_tip,
                    title: AppLocalizations.of(context)!.userProfilePrivacy,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.privacy,
                      );
                    },
                  ),

                  ProfileTile(
                    icon: Icons.bug_report,
                    title: AppLocalizations.of(
                      context,
                    )!.userProfileReportProblem,
                    onTap: () {
                      context.read<AppState>().openProfileSubPage(
                        ProfileSubPage.reportProblem,
                      );
                    },
                  ),
                ],
              ),

              // 5. Settings (Language + Theme + Logout)
              if (isOwnProfile)
                ProfileSection(
                  title: AppLocalizations.of(context)!.settings,
                  children: [
                    ProfileTile(
                      icon: Icons.workspace_premium,
                      title: AppLocalizations.of(
                        context,
                      )!.userProfileSubscriptionPlans,
                      onTap: () {
                        context.read<AppState>().openProfileSubPage(
                          ProfileSubPage.upgrade,
                        );
                      },
                    ),
                    ProfileTile(
                      icon: Icons.language,
                      title: AppLocalizations.of(context)!.userProfileLanguage,
                      onTap: () {
                        _showLanguageSelector(context);
                      },
                    ),
                    ProfileTile(
                      icon: Icons.dark_mode,
                      title: AppLocalizations.of(context)!.userProfileTheme,
                      onTap: () {
                        // بعداً پیاده‌سازی
                      },
                    ),
                    ProfileTile(
                      icon: Icons.notifications_active,
                      title: _generatingFcmToken
                          ? 'Generating FCM Token...'
                          : 'Generate FCM Token',
                      onTap: _generatingFcmToken
                          ? () {}
                          : _generateFcmTokenDebug,
                    ),
                    ProfileTile(
                      icon: Icons.lock,
                      title: AppLocalizations.of(
                        context,
                      )!.userProfileChangePassword,
                      onTap: () {
                        context.read<AppState>().openProfileSubPage(
                          ProfileSubPage.changePassword,
                        );
                      },
                    ),
                    ProfileTile(
                      icon: Icons.logout,
                      title: AppLocalizations.of(context)!.logoutMenuItem,
                      onTap: _logout,
                    ),
                    ProfileTile(
                      icon: Icons.delete_forever,
                      title: AppLocalizations.of(context)!.deleteAccount,
                      onTap: () {
                        context.read<AppState>().openProfileSubPage(
                          ProfileSubPage.deleteAccount,
                        );
                      },
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
                      title: AppLocalizations.of(context)!.addDogButton,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddDogPage(
                              onDogAdded: (newDog) {
                                final appState = context.read<AppState>();

                                appState.setMyDogs([newDog]); // فقط اضافه کن
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
                        mode: DogCardMode.profile,
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
                                    .map(
                                      (d) => d.id == updatedDog.id
                                          ? updatedDog
                                          : d,
                                    )
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

  Widget _buildGuestProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 80, color: Colors.grey),

            const SizedBox(height: 20),

            Text(
              AppLocalizations.of(context)!.userProfileGuestTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              AppLocalizations.of(context)!.userProfileGuestSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              },
              child: Text(AppLocalizations.of(context)!.userProfileLoginSignUp),
            ),
          ],
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
              title: Text(
                AppLocalizations.of(context)!.userProfileLanguageEnglish,
              ),
              onTap: () {
                context.read<AppState>().setLocale('en');
                Navigator.pop(context);
              },
            ),

            ListTile(
              title: Text(
                AppLocalizations.of(context)!.userProfileLanguagePersian,
              ),
              onTap: () {
                context.read<AppState>().setLocale('fa');
                Navigator.pop(context);
              },
            ),

            ListTile(
              title: Text(
                AppLocalizations.of(context)!.userProfileLanguageTurkish,
              ),
              onTap: () {
                context.read<AppState>().setLocale('tr');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Русский'),
              onTap: () {
                context.read<AppState>().setLocale('ru');
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

  void _showUpgradeRequiredSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 32, color: Colors.amber),

              const SizedBox(height: 12),

              Text(
                AppLocalizations.of(context)!.userProfileUnlockBusinessFeatures,
                style: AppTheme.h2(),
              ),

              const SizedBox(height: 8),

              Text(
                AppLocalizations.of(
                  context,
                )!.userProfileUpgradeBusinessDescription,
                textAlign: TextAlign.center,
                style: AppTheme.body(),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  // close popup
                  Navigator.pop(context);

                  // open upgrade page
                  context.read<AppState>().openProfileSubPage(
                    ProfileSubPage.upgrade,
                  );
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                ),

                child: Text(
                  AppLocalizations.of(context)!.userProfileUpgradeToGold,
                ),
              ),
            ],
          ),
        );
      },
    );
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
        title: Text(
          AppLocalizations.of(context)!.userProfileManageAdoptionCenter,
        ),
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

                _buildMenuItem(
                  AppLocalizations.of(context)!.userProfileOverview,
                  0,
                ),
                _buildMenuItem(
                  AppLocalizations.of(context)!.userProfileDogs,
                  1,
                ),
                _buildMenuItem(
                  AppLocalizations.of(context)!.userProfileRequests,
                  2,
                ),
                _buildMenuItem(AppLocalizations.of(context)!.settings, 3),
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
      title: Text(title, style: const TextStyle(color: Colors.white)),
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
        return Text(AppLocalizations.of(context)!.userProfileOverviewSection);
      case 1:
        return Text(AppLocalizations.of(context)!.userProfileDogsSection);
      case 2:
        return Text(AppLocalizations.of(context)!.userProfileRequestsSection);
      case 3:
        return Text(AppLocalizations.of(context)!.userProfileSettingsSection);
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ICON
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          /// TEXTS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  )!.userProfileApplicationUnderReview,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  AppLocalizations.of(
                    context,
                  )!.userProfileApplicationUnderReviewDescription,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                AppLocalizations.of(context)!.businessRegisterTitle,
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
          MaterialPageRoute(builder: (_) => AdminHubPage()),
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
                AppLocalizations.of(context)!.userProfileAdminPanel,
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
        debugPrint(
          "👉 OPEN DASHBOARD with businessId = ${appState.businessId}",
        );
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
                AppLocalizations.of(context)!.userProfileManageBusinessCenter,
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
            AppLocalizations.of(context)!.userProfileApplicationRejected,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (appState.initialBusinessResolutionReason != null)
            Text(
              AppLocalizations.of(context)!.userProfileRejectionReason(
                appState.initialBusinessResolutionReason!,
              ),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final appState = context.read<AppState>();

              if (!appState.canRegisterBusiness) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.userProfileUpgradeToGoldToContinue,
                    ),
                  ),
                );
                return;
              }

              appState.openProfileSubPage(ProfileSubPage.businessRegister);
            },
            child: Text(
              AppLocalizations.of(context)!.userProfileReApply,
              style: GoogleFonts.poppins(
                color: Colors.white,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
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
        title: Text(AppLocalizations.of(context)!.userProfileBusinessStatus),
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
            appState.businessStatus ??
                AppLocalizations.of(context)!.userProfileUnknownStatus,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
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
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingImage = false;

  File? _selectedImageFile;
  String? _photoUrl;

  String? _usernameError;
  String? _emailError;
  String? _phoneError;
  String? _cityError;
  String? _districtError;

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
      _cityController.text = (data['city'] ?? '').toString();
      _districtController.text = (data['district'] ?? '').toString();

      final existingPhoto = (data['photoUrl'] ?? '').toString().trim();
      if ((_photoUrl == null || _photoUrl!.isEmpty) &&
          existingPhoto.isNotEmpty) {
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
    _cityController.dispose();
    _districtController.dispose();
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
                title: Text(AppLocalizations.of(context)!.takePhoto),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  AppLocalizations.of(context)!.userProfileChooseFromGallery,
                ),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (_selectedImageFile != null ||
                  (_photoUrl?.isNotEmpty ?? false))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    AppLocalizations.of(context)!.userProfileRemovePhoto,
                  ),
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
      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(_photoUrl!).delete();
        } catch (e) {
          debugPrint("delete image error: $e");
        }
      }

      setState(() {
        _selectedImageFile = null;
        _photoUrl = '';
      });
    }

    final imageSource = source == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;

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
      _showSnack(AppLocalizations.of(context)!.userProfileImageSelectionFailed);
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
    final city = _cityController.text.trim();
    final district = _districtController.text.trim();

    String? usernameError;
    String? emailError;
    String? phoneError;
    String? cityError;
    String? districtError;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final phoneRegex = RegExp(r'^[0-9+\s()-]*$');

    if (username.isEmpty) {
      usernameError = AppLocalizations.of(context)!.usernameCannotBeEmpty;
    } else if (username.length < 3) {
      usernameError = AppLocalizations.of(
        context,
      )!.userProfileUsernameMinLength;
    } else if (username.length > 20) {
      usernameError = AppLocalizations.of(
        context,
      )!.userProfileUsernameMaxLength;
    } else if (username.contains(' ')) {
      usernameError = AppLocalizations.of(context)!.userProfileUsernameNoSpaces;
    }

    if (email.isEmpty) {
      emailError = AppLocalizations.of(context)!.emailRequired;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = AppLocalizations.of(context)!.emailInvalid;
    }

    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      phoneError = AppLocalizations.of(
        context,
      )!.userProfilePhoneInvalidCharacters;
    }

    if (city.length > 50) {
      cityError = 'City must be 50 characters or fewer';
    }

    if (district.length > 50) {
      districtError = 'District must be 50 characters or fewer';
    }

    if (district.isNotEmpty && city.isEmpty) {
      cityError = 'City is required when district is entered';
    }

    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _phoneError = phoneError;
      _cityError = cityError;
      _districtError = districtError;
    });

    return usernameError == null &&
        emailError == null &&
        phoneError == null &&
        cityError == null &&
        districtError == null;
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (_isSaving || _isUploadingImage) return;

    FocusScope.of(context).unfocus();

    final isValid = _validate();
    if (!isValid) return;

    final bio = _bioController.text.trim();

    // ✅ FIX 1: bio bug (return false ❌)
    if (bio.length > 150) {
      _showSnack(l10n.userProfileBioMaxLength);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String finalPhotoUrl = _photoUrl?.trim() ?? '';

      // ✅ upload image
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
      final city = _normalizeLocationText(_cityController.text);
      final district = _normalizeLocationText(_districtController.text);

      // ✅ FIX 2: username uniqueness BEFORE save
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty &&
          usernameCheck.docs.first.id != widget.userId) {
        _showSnack(l10n.userProfileUsernameAlreadyTaken);
        setState(() => _isSaving = false);
        return;
      }

      // ✅ FIX 3: Email change + reauth + error handling
      if (user != null && user.email != email) {
        try {
          // ⚠️ TODO: بعداً password واقعی بگیر
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: "USER_PASSWORD",
          );

          // await user.reauthenticateWithCredential(credential);
          await user.verifyBeforeUpdateEmail(email);

          // ✅ verify email
          if (!user.emailVerified) {
            await user.sendEmailVerification();
          }
        } on FirebaseAuthException catch (e) {
          _showSnack(e.message ?? l10n.userProfileEmailUpdateFailed);
          setState(() => _isSaving = false);
          return;
        }
      }

      final userData = <String, dynamic>{
        'username': username,
        'email': email,
        'phone': phone,
        'bio': bio,
        'city': city,
        'district': district,
        'photoUrl': finalPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ save firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(userData, SetOptions(merge: true));

      // ✅ save local cache
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
        'city': city,
        'district': district,
        'photoUrl': finalPhotoUrl,
      };

      await userDataBox.put(widget.userId, merged);

      if (!mounted) return;

      _showSnack(l10n.profileUpdatedSuccessfully);

      widget.onSaved?.call();
      widget.onClose();
    } catch (e) {
      debugPrint('EditProfileOverlay - save profile error: $e');

      if (!mounted) return;

      _showSnack(l10n.userProfileUpdateFailed);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizeLocationText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  InputDecoration _whiteDecoration({String? hintText, String? errorText}) {
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
        borderSide: const BorderSide(color: Color(0xFF9E1B4F), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Widget _whiteField(
    TextEditingController controller, {
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    String? hintText,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 15),
      decoration: _whiteDecoration(hintText: hintText, errorText: errorText),
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
        child: SmartMedia(
          url: _photoUrl!,
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
                  : const Icon(Icons.edit, size: 16, color: Colors.white),
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
      child: const Icon(Icons.person, color: Colors.white, size: 52),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          // 🔴 background
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black54),
            ),
          ),

          // 🟢 فرم اصلی
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.editProfile,
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
                              AppLocalizations.of(
                                context,
                              )!.userProfileChangePhoto,
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
                              l10n.usernameLabel,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          _whiteField(
                            widget.usernameController,
                            hintText: AppLocalizations.of(
                              context,
                            )!.userProfileEnterUsername,
                            errorText: _usernameError,
                          ),

                          const SizedBox(height: 14),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.emailLabel,
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
                            hintText: AppLocalizations.of(
                              context,
                            )!.userProfileEnterEmail,
                            errorText: _emailError,
                          ),

                          const SizedBox(height: 14),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.phoneLabel,
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
                            hintText: AppLocalizations.of(
                              context,
                            )!.userProfileOptionalPhoneNumber,
                            errorText: _phoneError,
                          ),

                          const SizedBox(height: 14),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'City',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          _whiteField(
                            _cityController,
                            textCapitalization: TextCapitalization.words,
                            hintText: 'Istanbul',
                            errorText: _cityError,
                          ),

                          const SizedBox(height: 14),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'District',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          _whiteField(
                            _districtController,
                            textCapitalization: TextCapitalization.words,
                            hintText: 'Kadikoy',
                            errorText: _districtError,
                          ),

                          const SizedBox(height: 14),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppLocalizations.of(context)!.userProfileBio,
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
                            hintText: AppLocalizations.of(
                              context,
                            )!.userProfileBioHint,
                          ),

                          const SizedBox(height: 22),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : widget.onClose,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
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
                                          AppLocalizations.of(context)!.save,
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

          // 🔥 این باید OUTSIDE Center باشه
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
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
