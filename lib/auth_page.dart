import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dog.dart';
import 'add_dog_page.dart';
import 'playmate_page.dart';
import 'terms_page.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/main.dart';

import 'package:barky_matches_fixed/home_gate.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';

import 'package:barky_matches_fixed/utils/firestore_cleaner.dart';

import 'package:lucide_icons/lucide_icons.dart';

const List<Map<String, String>> countryCodes = [
  {'name': 'Afghanistan', 'code': '+93'},
  {'name': 'Albania', 'code': '+355'},
  {'name': 'Algeria', 'code': '+213'},
  {'name': 'Andorra', 'code': '+376'},
  {'name': 'Angola', 'code': '+244'},
  {'name': 'Antigua and Barbuda', 'code': '+1-268'},
  {'name': 'Argentina', 'code': '+54'},
  {'name': 'Armenia', 'code': '+374'},
  {'name': 'Australia', 'code': '+61'},
  {'name': 'Austria', 'code': '+43'},
  {'name': 'Azerbaijan', 'code': '+994'},
  {'name': 'Bahamas', 'code': '+1-242'},
  {'name': 'Bahrain', 'code': '+973'},
  {'name': 'Bangladesh', 'code': '+880'},
  {'name': 'Barbados', 'code': '+1-246'},
  {'name': 'Belarus', 'code': '+375'},
  {'name': 'Belgium', 'code': '+32'},
  {'name': 'Belize', 'code': '+501'},
  {'name': 'Benin', 'code': '+229'},
  {'name': 'Bhutan', 'code': '+975'},
  {'name': 'Bolivia', 'code': '+591'},
  {'name': 'Bosnia and Herzegovina', 'code': '+387'},
  {'name': 'Botswana', 'code': '+267'},
  {'name': 'Brazil', 'code': '+55'},
  {'name': 'Brunei', 'code': '+673'},
  {'name': 'Bulgaria', 'code': '+359'},
  {'name': 'Burkina Faso', 'code': '+226'},
  {'name': 'Burundi', 'code': '+257'},
  {'name': 'Cambodia', 'code': '+855'},
  {'name': 'Cameroon', 'code': '+237'},
  {'name': 'Canada', 'code': '+1'},
  {'name': 'Cape Verde', 'code': '+238'},
  {'name': 'Central African Republic', 'code': '+236'},
  {'name': 'Chad', 'code': '+235'},
  {'name': 'Chile', 'code': '+56'},
  {'name': 'China', 'code': '+86'},
  {'name': 'Colombia', 'code': '+57'},
  {'name': 'Comoros', 'code': '+269'},
  {'name': 'Congo (DRC)', 'code': '+243'},
  {'name': 'Congo (Republic)', 'code': '+242'},
  {'name': 'Costa Rica', 'code': '+506'},
  {'name': 'Croatia', 'code': '+385'},
  {'name': 'Cuba', 'code': '+53'},
  {'name': 'Cyprus', 'code': '+357'},
  {'name': 'Czech Republic', 'code': '+420'},
  {'name': 'Denmark', 'code': '+45'},
  {'name': 'Djibouti', 'code': '+253'},
  {'name': 'Dominica', 'code': '+1-767'},
  {'name': 'Dominican Republic', 'code': '+1-809'},
  {'name': 'Ecuador', 'code': '+593'},
  {'name': 'Egypt', 'code': '+20'},
  {'name': 'El Salvador', 'code': '+503'},
  {'name': 'Equatorial Guinea', 'code': '+240'},
  {'name': 'Eritrea', 'code': '+291'},
  {'name': 'Estonia', 'code': '+372'},
  {'name': 'Eswatini', 'code': '+268'},
  {'name': 'Ethiopia', 'code': '+251'},
  {'name': 'Fiji', 'code': '+679'},
  {'name': 'Finland', 'code': '+358'},
  {'name': 'France', 'code': '+33'},
  {'name': 'Gabon', 'code': '+241'},
  {'name': 'Gambia', 'code': '+220'},
  {'name': 'Georgia', 'code': '+995'},
  {'name': 'Germany', 'code': '+49'},
  {'name': 'Ghana', 'code': '+233'},
  {'name': 'Greece', 'code': '+30'},
  {'name': 'Grenada', 'code': '+1-473'},
  {'name': 'Guatemala', 'code': '+502'},
  {'name': 'Guinea', 'code': '+224'},
  {'name': 'Guinea-Bissau', 'code': '+245'},
  {'name': 'Guyana', 'code': '+592'},
  {'name': 'Haiti', 'code': '+509'},
  {'name': 'Honduras', 'code': '+504'},
  {'name': 'Hungary', 'code': '+36'},
  {'name': 'Iceland', 'code': '+354'},
  {'name': 'India', 'code': '+91'},
  {'name': 'Indonesia', 'code': '+62'},
  {'name': 'Iran', 'code': '+98'},
  {'name': 'Iraq', 'code': '+964'},
  {'name': 'Ireland', 'code': '+353'},
  {'name': 'Israel', 'code': '+972'},
  {'name': 'Italy', 'code': '+39'},
  {'name': 'Jamaica', 'code': '+1-876'},
  {'name': 'Japan', 'code': '+81'},
  {'name': 'Jordan', 'code': '+962'},
  {'name': 'Kazakhstan', 'code': '+7'},
  {'name': 'Kenya', 'code': '+254'},
  {'name': 'Kiribati', 'code': '+686'},
  {'name': 'Kuwait', 'code': '+965'},
  {'name': 'Kyrgyzstan', 'code': '+996'},
  {'name': 'Laos', 'code': '+856'},
  {'name': 'Latvia', 'code': '+371'},
  {'name': 'Lebanon', 'code': '+961'},
  {'name': 'Lesotho', 'code': '+266'},
  {'name': 'Liberia', 'code': '+231'},
  {'name': 'Libya', 'code': '+218'},
  {'name': 'Liechtenstein', 'code': '+423'},
  {'name': 'Lithuania', 'code': '+370'},
  {'name': 'Luxembourg', 'code': '+352'},
  {'name': 'Madagascar', 'code': '+261'},
  {'name': 'Malawi', 'code': '+265'},
  {'name': 'Malaysia', 'code': '+60'},
  {'name': 'Maldives', 'code': '+960'},
  {'name': 'Mali', 'code': '+223'},
  {'name': 'Malta', 'code': '+356'},
  {'name': 'Marshall Islands', 'code': '+692'},
  {'name': 'Mauritania', 'code': '+222'},
  {'name': 'Mauritius', 'code': '+230'},
  {'name': 'Mexico', 'code': '+52'},
  {'name': 'Micronesia', 'code': '+691'},
  {'name': 'Moldova', 'code': '+373'},
  {'name': 'Monaco', 'code': '+377'},
  {'name': 'Mongolia', 'code': '+976'},
  {'name': 'Montenegro', 'code': '+382'},
  {'name': 'Morocco', 'code': '+212'},
  {'name': 'Mozambique', 'code': '+258'},
  {'name': 'Myanmar', 'code': '+95'},
  {'name': 'Namibia', 'code': '+264'},
  {'name': 'Nauru', 'code': '+674'},
  {'name': 'Nepal', 'code': '+977'},
  {'name': 'Netherlands', 'code': '+31'},
  {'name': 'New Zealand', 'code': '+64'},
  {'name': 'Nicaragua', 'code': '+505'},
  {'name': 'Niger', 'code': '+227'},
  {'name': 'Nigeria', 'code': '+234'},
  {'name': 'North Korea', 'code': '+850'},
  {'name': 'North Macedonia', 'code': '+389'},
  {'name': 'Norway', 'code': '+47'},
  {'name': 'Oman', 'code': '+968'},
  {'name': 'Pakistan', 'code': '+92'},
  {'name': 'Palau', 'code': '+680'},
  {'name': 'Panama', 'code': '+507'},
  {'name': 'Papua New Guinea', 'code': '+675'},
  {'name': 'Paraguay', 'code': '+595'},
  {'name': 'Peru', 'code': '+51'},
  {'name': 'Philippines', 'code': '+63'},
  {'name': 'Poland', 'code': '+48'},
  {'name': 'Portugal', 'code': '+351'},
  {'name': 'Qatar', 'code': '+974'},
  {'name': 'Romania', 'code': '+40'},
  {'name': 'Russia', 'code': '+7'},
  {'name': 'Rwanda', 'code': '+250'},
  {'name': 'Saint Kitts and Nevis', 'code': '+1-869'},
  {'name': 'Saint Lucia', 'code': '+1-758'},
  {'name': 'Saint Vincent and the Grenadines', 'code': '+1-784'},
  {'name': 'Samoa', 'code': '+685'},
  {'name': 'San Marino', 'code': '+378'},
  {'name': 'Sao Tome and Principe', 'code': '+239'},
  {'name': 'Saudi Arabia', 'code': '+966'},
  {'name': 'Senegal', 'code': '+221'},
  {'name': 'Serbia', 'code': '+381'},
  {'name': 'Seychelles', 'code': '+248'},
  {'name': 'Sierra Leone', 'code': '+232'},
  {'name': 'Singapore', 'code': '+65'},
  {'name': 'Slovakia', 'code': '+421'},
  {'name': 'Slovenia', 'code': '+386'},
  {'name': 'Solomon Islands', 'code': '+677'},
  {'name': 'Somalia', 'code': '+252'},
  {'name': 'South Africa', 'code': '+27'},
  {'name': 'South Korea', 'code': '+82'},
  {'name': 'South Sudan', 'code': '+211'},
  {'name': 'Spain', 'code': '+34'},
  {'name': 'Sri Lanka', 'code': '+94'},
  {'name': 'Sudan', 'code': '+249'},
  {'name': 'Suriname', 'code': '+597'},
  {'name': 'Sweden', 'code': '+46'},
  {'name': 'Switzerland', 'code': '+41'},
  {'name': 'Syria', 'code': '+963'},
  {'name': 'Taiwan', 'code': '+886'},
  {'name': 'Tajikistan', 'code': '+992'},
  {'name': 'Tanzania', 'code': '+255'},
  {'name': 'Thailand', 'code': '+66'},
  {'name': 'Togo', 'code': '+228'},
  {'name': 'Tonga', 'code': '+676'},
  {'name': 'Trinidad and Tobago', 'code': '+1-868'},
  {'name': 'Tunisia', 'code': '+216'},
  {'name': 'Turkey', 'code': '+90'},
  {'name': 'Turkmenistan', 'code': '+993'},
  {'name': 'Tuvalu', 'code': '+688'},
  {'name': 'Uganda', 'code': '+256'},
  {'name': 'Ukraine', 'code': '+380'},
  {'name': 'United Arab Emirates', 'code': '+971'},
  {'name': 'United Kingdom', 'code': '+44'},
  {'name': 'United States', 'code': '+1'},
  {'name': 'Uruguay', 'code': '+598'},
  {'name': 'Uzbekistan', 'code': '+998'},
  {'name': 'Vanuatu', 'code': '+678'},
  {'name': 'Vatican City', 'code': '+379'},
  {'name': 'Venezuela', 'code': '+58'},
  {'name': 'Vietnam', 'code': '+84'},
  {'name': 'Yemen', 'code': '+967'},
  {'name': 'Zambia', 'code': '+260'},
  {'name': 'Zimbabwe', 'code': '+263'},
];

Future<String?> safeGetFcmToken() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.getNotificationSettings();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('🚫 FCM token skipped (no permission)');
      return null;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final token = await messaging.getToken();
    return token;
  } catch (e) {
    debugPrint('FCM not ready yet (safe): $e');
    return null;
  }
}


// تابع اطمینان از مقداردهی اولیه Firebase
Future<void> ensureFirebase() async {
  if (Firebase.apps.isEmpty) {
    print('AuthPage - Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('AuthPage - Firebase initialized successfully');
  }
}

class VerifyEmailPage extends StatefulWidget {
  final String email;
 
final String userId;
final String requestId;


const VerifyEmailPage({
  super.key,
  required this.email,
  required this.userId,
  required this.requestId,
});

  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}



class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
static const String verifyEmailCodeUrl =
    'https://verifyemailcode-tj6s667gfq-ey.a.run.app';

  Future<void> _verifyCode(BuildContext context, Function onSuccess) async {
  final l10n = AppLocalizations.of(context)!;
  final code = _codeController.text.trim();

  if (code.length != 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter the 6-digit code')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final resp = await http.post(
      Uri.parse(verifyEmailCodeUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
  'email': widget.email,
  'code': code,
  'userId': widget.userId,
  'requestId': widget.requestId,
}),
    );

    final data = jsonDecode(resp.body);

    if (resp.statusCode == 200 && data['success'] == true) {
  await Hive.box<String>('currentUserBox')
      .put('emailVerified', 'true');

  await FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .set({
    'emailVerified': true,
  }, SetOptions(merge: true));

  // 🔥 مهم‌ترین خط
  await FirebaseAuth.instance.currentUser?.reload();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Email verified successfully')),
  );

  onSuccess();
} else {
      final msg = data['error'] ?? 'Invalid verification code';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  } catch (e) {
    debugPrint('VerifyEmailPage - Error verifying code: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    print('VerifyEmailPage - Building UI for email: ${widget.email}');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.verifyEmailTitle,
                style: GoogleFonts.dancingScript(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
  "Enter the verification code sent to your email",
  textAlign: TextAlign.center,
  style: GoogleFonts.poppins(
    color: Colors.white70,
    fontSize: 13,
  ),
),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: l10n.enterCodeLabel,
                  labelStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white24,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _verifyCode(context, () {
                          Navigator.pop(context, true);
                        }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.pink,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.pink)
                    : Text(l10n.verifyButton, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserInfo {
  final String username;
  final String email;
  final String? phone;
  final String password;
  const UserInfo({
  required this.username,
  required this.email,
  this.phone,
  required this.password,
});
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'phone': phone ?? '',
      'password': password,
    };
  }
  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      username: map['username'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      password: map['password'] as String,
    );
  }
}

class SimpleTestPage extends StatelessWidget {
  const SimpleTestPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    print('SimpleTestPage - Building UI');
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.simpleTestPageTitle),
      ),
      body: Center(
        child: Text(l10n.simpleTestPageMessage),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  final bool isLogin;

  final VoidCallback? onAuthSuccess; // 👈 برای login/signup
  final Function(Dog)? onDogAdded;   // 👈 فقط برای add dog

  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const AuthPage({
    super.key,
    required this.isLogin,
    this.onAuthSuccess,
    this.onDogAdded,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _AuthPageState createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _scrollController = ScrollController();
  final _phoneFocusNode = FocusNode();
  bool _isLogin = false;
  String _selectedCountryCode = '+90';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  bool _agreeToTerms = false;
  bool _receiveNews = false;
  bool _isLoading = false;
  late bool isLoginMode;
String? _emailVerificationRequestId;

  @override
void initState() {
  super.initState();

  final currentUserBox = Hive.box<String>('currentUserBox');
  _isLogin = widget.isLogin;
  _loadSavedCredentials();
}

@override
void didUpdateWidget(covariant AuthPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.isLogin != widget.isLogin) {
    isLoginMode = widget.isLogin;
  }
}

Future<void> _retryFcmToken() async {
  try {
    final currentUserId =
        Hive.box<String>('currentUserBox').get('currentUserId');

    if (currentUserId == null || currentUserId == 'guest') return;

    final fcmToken = await safeGetFcmToken();

    if (fcmToken != null && fcmToken.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({'fcmToken': fcmToken}, SetOptions(merge: true));

      debugPrint('AuthPage - Delayed FCM token saved');
    }
  } catch (e) {
    debugPrint('AuthPage - FCM retry failed (ignored): $e');
  }
}



  Future<void> _loadSavedCredentials() async {
  try {
    final currentUserBox = Hive.box<String>('currentUserBox');
await currentUserBox.delete('savedPassword');
    final currentUserId = currentUserBox.get('currentUserId');
    final savedEmail = currentUserBox.get('savedEmail');
    
    final rememberMe =
        currentUserBox.get('rememberMe', defaultValue: 'false');

    print('AuthPage - Checking currentUserId: $currentUserId');
    print(
        'AuthPage - Saved credentials → email=$savedEmail, rememberMe=$rememberMe');

    // 🔵 مهم: هیچ چیزی پاک نکن
    // فقط بررسی کن اگر RememberMe فعال است، فیلدها را پر کن

   if (rememberMe == 'true' && savedEmail != null) {
  setState(() {
    _emailController.text = savedEmail;
    _passwordController.text = '';
    _rememberMe = true;
  });

  print('AuthPage - Loaded saved email successfully');
} else {
      // اگر RememberMe فعال نیست فقط فیلدها خالی باشند
      setState(() {
        _emailController.text = '';
        _passwordController.text = '';
        _usernameController.text = '';
        _phoneController.text = '';
        _rememberMe = false;
      });

      print('AuthPage - RememberMe disabled or no saved data');
    }
  } catch (e) {
    print('AuthPage - Error loading saved credentials: $e');

    // در صورت خطا فقط فیلدها ریست شوند، چیزی پاک نشود
    setState(() {
      _emailController.text = '';
      _passwordController.text = '';
      _usernameController.text = '';
      _phoneController.text = '';
      _rememberMe = false;
    });
  }
}

  Future<void> _saveCredentials() async {
    final currentUserBox = Hive.box<String>('currentUserBox');
    if (_rememberMe) {
      await currentUserBox.put('savedEmail', _emailController.text.trim());
      
      await currentUserBox.put('rememberMe', 'true');
      print('AuthPage - Saved credentials: email=${_emailController.text}');
    } else {
      await currentUserBox.delete('savedEmail');
      await currentUserBox.delete('savedPassword');
      await currentUserBox.delete('rememberMe');
      print('AuthPage - Cleared saved credentials');
    }
  }

  Future<void> _saveLoginState() async {
    final currentUserBox = Hive.box<String>('currentUserBox');
    await currentUserBox.put('isLogin', _isLogin.toString());
    print('AuthPage - Saved login state: $_isLogin');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _signInWithFirebase(
  String email,
  String password,
) async {
  final l10n = AppLocalizations.of(context)!;
  final currentUserBox = Hive.box<String>('currentUserBox');
  final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');

  bool isAuthenticated = false;
  String? errorMessage;
  String userId = '';
  String? username;

  try {
    await ensureFirebase();

    final trimmedEmail = email.trim().toLowerCase();

    if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      return {
        'isAuthenticated': false,
        'errorMessage': l10n.emailInvalid,
        'userId': '',
        'username': null,
      };
    }

    final userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    final signedInUser = userCredential.user;

    if (signedInUser == null) {
      return {
        'isAuthenticated': false,
        'errorMessage': 'User not found',
        'userId': '',
        'username': null,
      };
    }

    userId = signedInUser.uid;

    Map<String, dynamic> userData = await _fetchUserDataIsolate(userId);

    if (userData.isEmpty) {
      userData = {
        'username': trimmedEmail.split('@')[0],
        'email': trimmedEmail,
        'phone': '',
        'isPremium': trimmedEmail == 'durbinistanbul@gmail.com',
        'emailVerified': false,
        'profileCompleted': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
    }

    if (userData['emailVerified'] == false) {
  return {
    'isAuthenticated': false,
    'errorMessage': 'Please verify your email before signing in.',
    'userId': '',
    'username': null,
  };
}

    if (userData['username'] == null ||
        userData['username'].toString().trim().isEmpty ||
        userData['username'] == 'User') {
      userData['username'] = trimmedEmail.split('@')[0];

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'username': userData['username'],
        'email': userData['email'] ?? trimmedEmail,
        'phone': userData['phone'] ?? '',
        'isPremium': userData['isPremium'] ?? false,
        'emailVerified': userData['emailVerified'] ?? false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final fcmToken = await safeGetFcmToken();

    if (fcmToken != null && fcmToken.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
      }, SetOptions(merge: true));
    }

    final lowerCaseUserId = userId.toLowerCase();

    if (userDataBox.containsKey(lowerCaseUserId)) {
      await userDataBox.delete(lowerCaseUserId);
    }

    final cleanedData = cleanDeep(Map<String, dynamic>.from(userData));

    await userDataBox.put(userId, cleanedData);
    await currentUserBox.put('currentUserId', userId);
    await currentUserBox.put(
      'username_$userId',
      userData['username']?.toString() ?? trimmedEmail.split('@')[0],
    );

    await _saveCredentials();

    username = userData['username']?.toString() ?? trimmedEmail.split('@')[0];
    isAuthenticated = true;

    return {
      'isAuthenticated': isAuthenticated,
      'errorMessage': errorMessage,
      'userId': userId,
      'username': username,
    };
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'user-not-found':
        errorMessage = l10n.userNotFound;
        break;
      case 'wrong-password':
      case 'invalid-credential':
        errorMessage = l10n.incorrectPassword;
        break;
      case 'invalid-email':
        errorMessage = l10n.emailInvalid;
        break;
      default:
        errorMessage = l10n.errorOccurred(e.message ?? e.code);
    }

    return {
      'isAuthenticated': false,
      'errorMessage': errorMessage,
      'userId': '',
      'username': null,
    };
  } catch (e) {
    return {
      'isAuthenticated': false,
      'errorMessage': l10n.errorOccurred(e.toString()),
      'userId': '',
      'username': null,
    };
  }
}

static Future<Map<String, dynamic>> _fetchUserDataIsolate(
  String userId,
) async {
  try {
    await ensureFirebase();

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!doc.exists) {
      return <String, dynamic>{};
    }

    final raw = Map<String, dynamic>.from(doc.data() ?? {});
    final cleaned = cleanDeep(raw);

    return Map<String, dynamic>.from(cleaned);
  } catch (e) {
    debugPrint('AuthPage - Error fetching user data: $e');
    return <String, dynamic>{};
  }
}

Future<Map<String, dynamic>> _registerWithFirebase(
  String email,
  String password,
  String username,
  String? phone,
) async {
  final l10n = AppLocalizations.of(context)!;

  try {
    await ensureFirebase();

    final trimmedEmail = email.trim().toLowerCase();

    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    final user = cred.user;

    if (user == null) {
      return {
        'success': false,
        'userId': null,
        'errorMessage': 'User creation failed',
      };
    }

    final userId = user.uid;
String? requestId;
    try {
      final encodedEmail = Uri.encodeQueryComponent(trimmedEmail);

      final resp = await http.get(
  Uri.parse(
    'https://sendverificationcode-tj6s667gfq-ey.a.run.app?email=$encodedEmail',
  ),
);

if (resp.statusCode != 200) {
  debugPrint('⚠️ verification API failed: ${resp.body}');

  return {
    'success': false,
    'userId': userId,
    'requestId': null,
    'errorMessage': 'Verification email could not be sent',
  };
}

final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
requestId = decoded['requestId']?.toString();

if (requestId == null || requestId.isEmpty) {
  return {
    'success': false,
    'userId': userId,
    'requestId': null,
    'errorMessage': 'Verification session could not be created',
  };
}
    } catch (e) {
      debugPrint('⚠️ verification API error: $e');

      return {
        'success': false,
        'userId': userId,
        'errorMessage': 'Verification email could not be sent',
      };
    }

    final userData = {
      'username': username.trim(),
      'email': trimmedEmail,
      'phone': (phone ?? '').trim(),
      'isPremium': false,
      'emailVerified': false,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(userData, SetOptions(merge: true));

    final fcmToken = await safeGetFcmToken();

    if (fcmToken != null && fcmToken.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
      }, SetOptions(merge: true));
    }

    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');

    final hiveUserData = Map<String, dynamic>.from(userData)
      ..['createdAt'] = DateTime.now().toIso8601String();

    hiveUserData.removeWhere((key, value) => value == null);

    await userDataBox.put(userId, hiveUserData);

    return {
  'success': true,
  'userId': userId,
  'requestId': requestId,
  'errorMessage': null,
};
  } on FirebaseAuthException catch (e) {
    String msg;

    switch (e.code) {
      case 'email-already-in-use':
        msg = 'This email is already registered. Try logging in.';
        break;
      case 'invalid-email':
        msg = l10n.emailInvalid;
        break;
      case 'weak-password':
        msg =
            'Password must be at least 8 characters and include letters and numbers.';
        break;
      default:
        msg = l10n.errorOccurred(e.message ?? e.code);
    }

    return {
      'success': false,
      'userId': null,
      'requestId': null,
      'errorMessage': msg,
    };
  } catch (e) {
    return {
      'success': false,
      'userId': null,
      'requestId': null,
      'errorMessage': l10n.errorOccurred(e.toString()),
    };
  }
}

  void _openTermsPage() {
    print('AuthPage - Attempting to open TermsPage');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TermsPage()),
      );
      print('AuthPage - Successfully navigated to TermsPage');
    } catch (e) {
      print('AuthPage - Error navigating to TermsPage: $e');
    }
  }

  void _openSimpleTestPage() {
    print('AuthPage - Attempting to open SimpleTestPage');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SimpleTestPage()),
      );
      print('AuthPage - Successfully navigated to SimpleTestPage');
    } catch (e) {
      print('AuthPage - Error navigating to SimpleTestPage: $e');
    }
  }

  void _forgotPassword() {
  final l10n = AppLocalizations.of(context)!;
  final TextEditingController emailController =
      TextEditingController(text: _emailController.text);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// 🔥 TITLE
              Text(
                "Forgot Password",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              /// 📝 DESCRIPTION
              Text(
                "Enter your email to reset your password",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 16),

              /// 📧 EMAIL INPUT
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: "Email address",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black38,
                  ),
                  prefixIcon: const Icon(LucideIcons.mail),
                  filled: true,
                  fillColor: const Color(0xFFFFF3F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// 🔘 BUTTONS
              Row(
                children: [

                  /// CANCEL
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  /// SEND
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = emailController.text.trim();

                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.emailRequired)),
                          );
                          return;
                        }

                        try {
                          await http.post(
                            Uri.parse(
                              "https://europe-west3-barkymatches-new.cloudfunctions.net/sendPasswordResetCustom",
                            ),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({"email": email}),
                          );

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Password reset email sent 📩"),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.errorOccurred(e.toString())),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Send",
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
      );
    },
  );
}

  void _logout() {
    final l10n = AppLocalizations.of(context)!;
    print('AuthPage - Logging out...');
    try {
      AuthTrap.signOut(reason: 'session_expired');
      print('AuthPage - Signed out from Firebase');
      final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
      final currentUserBox = Hive.box<String>('currentUserBox');
      final dogsBox = Hive.box<Dog>('dogsBox');
      currentUserBox.clear();
      userDataBox.clear();
      dogsBox.clear();
      print('AuthPage - Cleared userBox, userDataBox, and dogsBox');
      SharedPreferences.getInstance().then((prefs) {
        prefs.clear();
        print('AuthPage - Cleared saved credentials from SharedPreferences');
      });
      if (mounted && context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (Route<dynamic> route) => false,
        );
        print('AuthPage - Navigated to WelcomePage after logout');
      }
    } catch (e) {
      print('AuthPage - Error during logout: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  void _submit() async {
  final l10n = AppLocalizations.of(context)!;
  print('AuthPage - Submit button pressed');
  print('AuthPage - Form validation started');
  print('AuthPage - Email: ${_emailController.text}');
  print('AuthPage - Password: ${_passwordController.text}');
  print('AuthPage - Confirm Password: ${_confirmPasswordController.text}');
  print('AuthPage - Username: ${_usernameController.text}');
  print('AuthPage - Phone: ${_phoneController.text}');
  print('AuthPage - Terms Accepted: $_agreeToTerms');

  if (!_formKey.currentState!.validate()) {
    print('AuthPage - Validation failed: All fields must be filled');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillRequiredFields)),
      );
    }
    return;
  }

  if (!mounted) return;
  setState(() {
    _isLoading = true;
  });

  try {
    if (_isLogin) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final Map<String, dynamic> result =
          await _signInWithFirebase(email, password);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      final bool isAuthenticated = result['isAuthenticated'] ?? false;
      final String? errorMessage = result['errorMessage'];
      final String userId = result['userId'] ?? '';

      if (isAuthenticated && userId.isNotEmpty && mounted) {
        final appState = context.read<AppState>();
        appState.updateUserId(userId);

        // فقط یک‌بار init
        await appState.initUser();
        await _askNotificationPermissionAfterLogin();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const HomeGate()),
  (route) => false,
);
      } else if (errorMessage != null && mounted && context.mounted) {
        print('AuthPage - Sign-in failed: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } else {
      if (!_agreeToTerms) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.termsRequired)),
          );
        }
        return;
      }

      final username = _usernameController.text.trim();
final email = _emailController.text.trim();
final password = _passwordController.text.trim(); // ✅ باید اینجا باشه
debugPrint("📧 EMAIL = $email");
debugPrint("🔑 PASSWORD = $password");
debugPrint("👤 USERNAME = $username");
final phone = _phoneController.text.trim().isEmpty
    ? null
    : '$_selectedCountryCode${_phoneController.text.trim()}';

await Future.delayed(const Duration(milliseconds: 500));

final Map<String, dynamic> result =
    await _registerWithFirebase(email, password, username, phone);
      

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      final bool success = result['success'] ?? false;

final String? errorMessage = result['errorMessage'];
final String? userId = result['userId'];   // ✅ اضافه کن
final String? requestId = result['requestId'];
      

      if (success &&
    userId != null &&
    requestId != null &&
    mounted &&
    context.mounted) {
        final currentUserBoxStorage = Hive.box<String>('currentUserBox');
        await currentUserBoxStorage.put(
          'receiveNews',
          _receiveNews.toString(),
        );
        print('AuthPage - Receive news preference saved: $_receiveNews');

        Navigator.push(
          context,
          MaterialPageRoute(
           builder: (context) => VerifyEmailPage(
  email: email,
  userId: userId!,
  requestId: requestId!,
),
          ),
        ).then((isVerified) async {
          if (!mounted) return;

          if (isVerified == true && context.mounted) {
            await Hive.box<String>('currentUserBox').put('currentUserId', userId);
            Provider.of<AppState>(context, listen: false)
                .updateUserId(userId);

            print(
                'AuthPage - Navigation to PlaymatePage after verification triggered');

            Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const HomeGate()),
  (route) => false,
);
          } else if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.verifyEmailTitle)),
            );
          }
        });
      } else if (errorMessage != null && mounted && context.mounted) {
        print('AuthPage - Registration failed: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  } catch (e) {
    print('AuthPage - Error during login/signup: $e');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
      );
    }
  }
}


Future<void> _askNotificationPermissionAfterLogin() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      final result = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('🔔 Notification permission result: ${result.authorizationStatus}');
    }
  } catch (e) {
    debugPrint('Permission request error: $e');
  }
}

  @override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  print('AuthPage - Building UI (isLogin: $_isLogin) - Versioning');

  const Color primaryPink = Colors.pink;
  const Color accentYellow = Color(0xFFFFC107);
  const Color darkPink = Color(0xFF9E1B4F);

  return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
      print('GestureDetector - Screen tapped, keyboard dismissed');
    },
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE91E63),
              Color(0xFFFF5A9E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  Container(
  width: 92,
  height: 92,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.18),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Image.asset(
      'assets/image/logo.png',
      fit: BoxFit.contain,
    ),
  ),
),

                  const SizedBox(height: 18),

                  Text(
                    _isLogin ? l10n.signInTitle : l10n.signUpTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pacifico(
                      fontSize: 34,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _isLogin
                        ? 'Welcome back to BarkyMatches'
                        : 'Create your BarkyMatches account',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: _authInputDecoration(
                              label: l10n.usernameLabel,
                              icon: Icons.person_outline,
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.usernameRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _emailController,
                          decoration: _authInputDecoration(
  label: l10n.emailLabel,
  icon: LucideIcons.mail,
),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return l10n.emailRequired;
                            }

                            final emailRegex =
                                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                            if (!emailRegex.hasMatch(email)) {
                              return l10n.emailInvalid;
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        if (!_isLogin) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.pink.withOpacity(0.12),
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: darkPink,
                              ),
                              underline: const SizedBox(),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              items: countryCodes.map((country) {
                                return DropdownMenuItem<String>(
                                  value: country['code']!,
                                  child: Text(
                                    '${country['name']} (${country['code']})',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (mounted) {
                                  setState(() {
                                    _selectedCountryCode = value!;
                                    print(
                                      'Country code changed to: $_selectedCountryCode',
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            decoration: _authInputDecoration(
                              label: l10n.phoneLabel,
                              icon: LucideIcons.phone,
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;

                              final digits =
                                  text.replaceAll(RegExp(r'[^0-9]'), '');

                              if (digits.length < 7) {
                                return 'Phone number is too short';
                              }

                              return null;
                            },
                            onChanged: (value) {
                              print('AuthPage - Phone input: $value');
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _passwordController,
                          decoration: _authInputDecoration(
                            label: l10n.passwordLabel,
                            icon: LucideIcons.lock,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
    ? LucideIcons.eye
    : LucideIcons.eyeOff,
                                color: darkPink,
                              ),
                              onPressed: () {
                                if (mounted) {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                }
                              },
                            ),
                          ),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.passwordRequired;
                            }

                            final passwordRegex = RegExp(
                              r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
                            );

                            if (!passwordRegex.hasMatch(value)) {
                              return l10n.passwordValidation;
                            }

                            return null;
                          },
                        ),

                        if (_isLogin) ...[
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  }
                                },
                                checkColor: Colors.white,
                                activeColor: primaryPink,
                                side: BorderSide(
                                  color: Colors.pink.withOpacity(0.45),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  l10n.rememberMeLabel,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _forgotPassword,
                                child: Text(
                                  l10n.forgotPasswordLabel,
                                  style: GoogleFonts.poppins(
                                    color: darkPink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (!_isLogin) ...[
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: _authInputDecoration(
                              label: l10n.confirmPasswordLabel,
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? LucideIcons.eye
    : LucideIcons.eyeOff,
                                  color: darkPink,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  }
                                },
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            obscureText: _obscureConfirmPassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.confirmPasswordRequired;
                              }

                              if (value != _passwordController.text) {
                                return l10n.passwordMismatch;
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      _agreeToTerms = value ?? false;
                                    });
                                  }
                                },
                                checkColor: Colors.white,
                                activeColor: primaryPink,
                                side: BorderSide(
                                  color: Colors.pink.withOpacity(0.45),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: GestureDetector(
                                    onTap: _openTermsPage,
                                    child: Text.rich(
                                      TextSpan(
                                        text: l10n.termsAndConditionsLabel
                                            .split('Terms and Conditions')[0],
                                        style: GoogleFonts.poppins(
                                          color: Colors.black87,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Terms and Conditions',
                                            style: GoogleFonts.poppins(
                                              color: darkPink,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Checkbox(
                                value: _receiveNews,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      _receiveNews = value ?? false;
                                    });
                                  }
                                },
                                checkColor: Colors.white,
                                activeColor: primaryPink,
                                side: BorderSide(
                                  color: Colors.pink.withOpacity(0.45),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  l10n.receiveNewsLabel,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_isLogin || _agreeToTerms) &&
                                    !_isLoading
                                ? _submit
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentYellow,
                              disabledBackgroundColor:
                                  Colors.grey.withOpacity(0.25),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    _isLogin
                                        ? l10n.signInButton
                                        : l10n.signUpButton,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _isLogin = !_isLogin;
                                _saveLoginState();
                              });
                            }
                          },
                          child: Text(
                            _isLogin
                                ? l10n.noAccountSignUp
                                : l10n.haveAccountSignIn,
                            style: GoogleFonts.poppins(
                              color: darkPink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();

                        final currentUserBox =
                            Hive.box<String>('currentUserBox');
                        await currentUserBox.put('currentUserId', 'guest');

                        final appState = context.read<AppState>();
                        appState.setGuestUser();

                        debugPrint('🚫 Guest mode → no notification permission');

                        if (!mounted) return;

                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeGate()),
                          (route) => false,
                        );
                      } catch (e) {
                        debugPrint('Guest login error: $e');
                      }
                    },
                    child: Text(
                      l10n.continueAsGuest,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
InputDecoration _authInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  const Color darkPink = Color(0xFF9E1B4F);

  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(
      color: Colors.black54,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(
      icon,
      color: darkPink,
      size: 21,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFFFF3F7),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 15,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.pink.withOpacity(0.10),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFFFC107),
        width: 1.6,
      ),
    ),
  );
}
}


