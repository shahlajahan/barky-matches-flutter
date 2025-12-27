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
  final String verificationCode;
  const VerifyEmailPage({super.key, required this.email, required this.verificationCode});
  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  void _verifyCode(BuildContext context, Function onSuccess) async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeController.text.trim() == widget.verificationCode) {
      setState(() {
        _isLoading = true;
      });
      try {
        await Hive.box<String>('currentUserBox').put('verified_${widget.email}', 'true');
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.verifyEmailTitle)),
          );
          onSuccess();
        }
      } catch (e) {
        print('VerifyEmailPage - Error verifying code: $e');
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred('Invalid verification code'))),
        );
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
                l10n.verificationCodeSent(widget.email),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
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
  final String phone;
  final String password;
  const UserInfo({
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
  final Function(Dog)? onDogAdded;
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
  const AuthPage({
    super.key,
    required this.isLogin,
    required this.onDogAdded,
    required this.dogsList,
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

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    BackgroundIsolateBinaryMessenger.ensureInitialized(RootIsolateToken.instance!);
    final currentUserBox = Hive.box<String>('currentUserBox');
    final isLoginString = currentUserBox.get('isLogin', defaultValue: widget.isLogin.toString());
    _isLogin = isLoginString == 'true';
    print('AuthPage - Initial isLogin: $_isLogin');
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final currentUserBox = Hive.box<String>('currentUserBox');
      final currentUserId = currentUserBox.get('currentUserId');
      print('AuthPage - Checking currentUserId: $currentUserId');
      if (currentUserId == null) {
        print('AuthPage - No current user, skipping credential load');
        setState(() {
          _emailController.text = '';
          _passwordController.text = '';
          _usernameController.text = '';
          _phoneController.text = '';
          _rememberMe = false;
        });
        await currentUserBox.clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('AuthPage - Cleared all data after logout');
        return;
      }
      final savedEmail = currentUserBox.get('savedEmail');
      final savedPassword = currentUserBox.get('savedPassword');
      final rememberMe = currentUserBox.get('rememberMe', defaultValue: 'false');
      print('AuthPage - Loading saved credentials: email=$savedEmail, password=$savedPassword, rememberMe=$rememberMe');
      if (rememberMe == 'true' && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
        print('AuthPage - Successfully loaded saved credentials: email=$savedEmail');
      } else {
        print('AuthPage - No saved credentials found or Remember Me is disabled');
        setState(() {
          _emailController.text = '';
          _passwordController.text = '';
          _usernameController.text = '';
          _phoneController.text = '';
          _rememberMe = false;
        });
        await currentUserBox.delete('savedEmail');
        await currentUserBox.delete('savedPassword');
        await currentUserBox.delete('rememberMe');
        print('AuthPage - Cleared saved credentials due to missing data');
      }
    } catch (e) {
      print('AuthPage - Error loading saved credentials: $e');
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
      await currentUserBox.put('savedPassword', _passwordController.text.trim());
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

  Future<Map<String, dynamic>> _signInWithFirebase(String email, String password) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUserBox = Hive.box<String>('currentUserBox');
    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    bool isAuthenticated = false;
    String? errorMessage;
    String userId = '';
    String? username;
    try {
      print('AuthPage - Ensuring Firebase is initialized before sign-in...');
      await ensureFirebase();
      print('AuthPage - Firebase initialization confirmed');
      final startTime = DateTime.now();
      print('AuthPage - Sign-in started at: ${startTime.toIso8601String()}');
      print('AuthPage - Attempting to sign in with email: "$email"');
      if (!email.contains('@') || !email.contains('.')) {
        print('AuthPage - Invalid email format detected: $email');
        errorMessage = l10n.emailInvalid;
        return {
          'isAuthenticated': isAuthenticated,
          'errorMessage': errorMessage,
          'userId': userId,
          'username': username,
        };
      }
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await userCredential.user?.reload();
      await Future.delayed(const Duration(seconds: 1)); // تأخیر برای اطمینان از توکن
      userId = userCredential.user!.uid;
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': fcmToken,
        }, SetOptions(merge: true));
        print('AuthPage - FCM token updated for user $userId: $fcmToken');
      }
      final lowerCaseUserId = userId.toLowerCase();
      if (userDataBox.containsKey(lowerCaseUserId)) {
        await userDataBox.delete(lowerCaseUserId);
        print('AuthPage - Deleted lowercase userId from userDataBox: $lowerCaseUserId');
      }
      Map<String, dynamic> userData = await _fetchUserDataIsolate(userId);
      if (userData.isEmpty) {
        print('AuthPage - No user data found for userId: $userId');
        userData = {
          'username': email.split('@')[0],
          'email': email,
          'phone': '',
          'password': '',
          'isPremium': email == 'durbinistanbul@gmail.com' ? true : false,
          'createdAt': DateTime.now().toIso8601String(),
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(userData, SetOptions(merge: true));
        print('AuthPage - Created new user data for userId: $userId in Firestore');
      }
      if (userData['username'] == null || userData['username'].isEmpty || userData['username'] == 'User') {
        userData['username'] = email.split('@')[0];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
              'username': userData['username'],
              'email': userData['email'],
              'phone': userData['phone'],
              'password': userData['password'],
              'isPremium': userData['isPremium'],
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        print('AuthPage - Updated username in Firestore: ${userData['username']}');
      }
      final hiveUserData = Map<String, dynamic>.from(userData);
      if (hiveUserData.containsKey('createdAt') && (hiveUserData['createdAt'] is FieldValue || hiveUserData['createdAt'] is Timestamp)) {
        hiveUserData['createdAt'] = DateTime.now().toIso8601String();
      }
      await userDataBox.put(userId, hiveUserData);
      print('AuthPage - Stored user data in userDataBox with key $userId: $hiveUserData');
      await currentUserBox.put('currentUserId', userId);
      print('AuthPage - Stored currentUserId: $userId');
      await _saveCredentials();
      await currentUserBox.put('username_$userId', userData['username']);
      print('AuthPage - Stored username in userBox: ${userData['username']}');
      username = userData['username'];
      isAuthenticated = true;
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('AuthPage - Sign-in completed at: ${endTime.toIso8601String()}');
      print('AuthPage - Sign-in took: ${duration.inMilliseconds} milliseconds');
      return {
        'isAuthenticated': isAuthenticated,
        'errorMessage': errorMessage,
        'userId': userId,
        'username': username,
      };
    } catch (e) {
      print('AuthPage - Error signing in: $e');
      errorMessage = l10n.errorOccurred(e.toString());
      if (errorMessage?.contains('user-not-found') ?? false) {
        errorMessage = l10n.userNotFound;
      } else if (errorMessage?.contains('wrong-password') ?? false) {
        errorMessage = l10n.incorrectPassword;
      }
      return {
        'isAuthenticated': isAuthenticated,
        'errorMessage': errorMessage,
        'userId': userId,
        'username': username,
      };
    }
  }

  static Future<Map<String, dynamic>> _fetchUserDataIsolate(String userId) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      BackgroundIsolateBinaryMessenger.ensureInitialized(RootIsolateToken.instance!);
      await ensureFirebase();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) {
        print('AuthPage - No user data found for userId: $userId');
        return {};
      }
      final data = doc.data() ?? {};
      if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      return data;
    } catch (e) {
      print('AuthPage - Error fetching user data: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _registerWithFirebase(
      String email,
      String password,
      String username,
      String phone,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ensureFirebase();
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final userId = cred.user!.uid;
      final userData = {
        'username': username.trim(),
        'email': email,
        'phone': phone,
        'password': '',
        'isPremium': email == 'durbinistanbul@gmail.com',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'fcmToken': fcmToken}, SetOptions(merge: true));
        print('AuthPage - FCM token updated for user $userId: $fcmToken');
      }
      final tempKey = 'temp_${email.split('@')[0]}';
      final tempDoc = await FirebaseFirestore.instance.collection('users').doc(tempKey).get();
      if (tempDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(tempDoc.data()!, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc(tempKey).delete();
        print('AuthPage - Migrated temporary user data for $email to $userId');
        final tempDogKey = '${email.split('@')[0]}_temp_${email.split('@')[0]}';
        final tempDogDoc =
            await FirebaseFirestore.instance.collection('dogs').doc(tempDogKey).get();
        if (tempDoc.exists) {
          final dogId = FirebaseFirestore.instance.collection('dogs').doc().id;
          await FirebaseFirestore.instance
              .collection('dogs')
              .doc(dogId)
              .set({
            ...tempDogDoc.data()!,
            'id': dogId,
            'ownerId': userId,
            'name': username.trim(),
          });
          await FirebaseFirestore.instance.collection('dogs').doc(tempDogKey).delete();
          print('AuthPage - Migrated dog data for ${email.split('@')[0]} to dogId: $dogId');
        }
      }
      final dogId = FirebaseFirestore.instance.collection('dogs').doc().id;
      final dogDoc =
          await FirebaseFirestore.instance.collection('dogs').doc(dogId).get();
      if (!dogDoc.exists) {
        final dogData = {
          'id': dogId,
          'name': username.trim(),
          'breed': l10n.unknownBreed,
          'age': 1,
          'gender': l10n.unknownGender,
          'healthStatus': l10n.healthHealthy,
          'isNeutered': false,
          'description': l10n.descriptionPlaceholder.replaceFirst('{username}', username.trim()),
          'traits': [l10n.traitFriendly],
          'ownerGender': l10n.dogDetailsOwnerGenderPreferNotToSay,
          'imagePaths': [],
          'isAvailableForAdoption': false,
          'isOwner': true,
          'ownerId': userId,
          'latitude': 41.0103,
          'longitude': 28.6724,
        };
        await FirebaseFirestore.instance.collection('dogs').doc(dogId).set(dogData);
        final dogsBox = Hive.box<Dog>('dogsBox');
        await dogsBox.put(
          dogId,
          Dog(
            id: dogId,
            name: dogData['name'] as String,
            breed: dogData['breed'] as String,
            age: dogData['age'] as int,
            gender: dogData['gender'] as String,
            healthStatus: dogData['healthStatus'] as String,
            isNeutered: dogData['isNeutered'] as bool,
            description: dogData['description'] as String?,
            traits: List<String>.from(dogData['traits'] as Iterable<dynamic>),
            ownerGender: dogData['ownerGender'] as String?,
            imagePaths: const [],
            isAvailableForAdoption: dogData['isAvailableForAdoption'] as bool,
            isOwner: dogData['isOwner'] as bool,
            ownerId: userId,
            latitude: dogData['latitude'] as double?,
            longitude: dogData['longitude'] as double?,
          ),
        );
        print('AuthPage - Created and stored default dog in Hive for user: ${username.trim()}, userId: $userId, dogId: $dogId');
      }
      final resp = await http.get(Uri.parse(
    'https://sendverificationcode-tj6s667gfq-ey.a.run.app?email=$email'));
      if (resp.statusCode != 200) {
        throw Exception(l10n.errorOccurred('Failed to fetch verification code: ${resp.body}'));
      }
      final data = jsonDecode(resp.body);
      final verificationCode = data['verificationCode'] as String;
      final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
      final hiveUserData = Map<String, dynamic>.from(userData);
      hiveUserData['createdAt'] = DateTime.now().toIso8601String();
      await userDataBox.put(userId, hiveUserData);
      await Hive.box<String>('currentUserBox').put('currentUserId', userId);
      return {
        'success': true,
        'userId': userId,
        'verificationCode': verificationCode,
        'errorMessage': null,
      };
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? e.code;
      if (e.code == 'email-already-in-use') {
        msg = l10n.emailInvalid;
      } else if (e.code == 'invalid-email') {
        msg = l10n.emailInvalid;
      } else if (e.code == 'weak-password') {
        msg = l10n.passwordValidation;
      }
      print('AuthPage - FirebaseAuthException during register: ${e.code} $msg');
      return {
        'success': false,
        'userId': null,
        'verificationCode': null,
        'errorMessage': msg,
      };
    } catch (e) {
      print('AuthPage - Error registering user: $e');
      return {
        'success': false,
        'userId': null,
        'verificationCode': null,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forgotPasswordDialogTitle),
        content: Text(l10n.forgotPasswordDialogMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.emailRequired)),
                  );
                }
                return;
              }
              try {
                await ensureFirebase();
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                Navigator.pop(context);
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordResetSent(email))),
                  );
                }
              } catch (e) {
                print('AuthPage - Error sending password reset email: $e');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
                  );
                }
              }
            },
            child: Text(l10n.sendButton),
          ),
        ],
      ),
    );
  }

  void _logout() {
    final l10n = AppLocalizations.of(context)!;
    print('AuthPage - Logging out...');
    try {
      FirebaseAuth.instance.signOut();
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
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        if (_isLogin) {
          final email = _emailController.text.trim();
          final password = _passwordController.text.trim();
          Map<String, dynamic> result = await _signInWithFirebase(email, password);
          setState(() {
            _isLoading = false;
          });
          bool isAuthenticated = result['isAuthenticated'] ?? false;
          String? errorMessage = result['errorMessage'];
          String? username = result['username'];
          String userId = result['userId'] ?? '';
          if (isAuthenticated && userId.isNotEmpty && mounted && context.mounted) {
            final dogsBox = Hive.box<Dog>('dogsBox');
            print('AuthPage - Navigating to PlaymatePage with userId: $userId');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => PlaymatePage(
                  dogs: dogsBox.values.toList(),
                  favoriteDogs: widget.favoriteDogs,
                  onToggleFavorite: widget.onToggleFavorite,
                  currentUserId: userId,
                ),
              ),
              (Route<dynamic> route) => false,
            );
            print('AuthPage - Navigation to PlaymatePage triggered');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.welcomeBack(username ?? ''))),
            );
          } else if (errorMessage != null && mounted && context.mounted) {
            print('AuthPage - Sign-in failed: $errorMessage');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        } else {
          if (!_agreeToTerms) {
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
          final phone = _phoneController.text.trim();
          final password = _passwordController.text.trim();
          Map<String, dynamic> result = await _registerWithFirebase(email, password, username, phone);
          setState(() {
            _isLoading = false;
          });
          bool success = result['success'] ?? false;
          String? verificationCode = result['verificationCode'];
          String? errorMessage = result['errorMessage'];
          String? userId = result['userId'];
          if (success && userId != null && mounted && context.mounted) {
            final currentUserBoxStorage = Hive.box<String>('currentUserBox');
            await currentUserBoxStorage.put('receiveNews', _receiveNews.toString());
            print('AuthPage - Receive news preference saved: $_receiveNews');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyEmailPage(
                  email: email,
                  verificationCode: verificationCode!,
                ),
              ),
            ).then((isVerified) {
              if (isVerified == true && mounted && context.mounted) {
                final dogsBox = Hive.box<Dog>('dogsBox');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaymatePage(
                      dogs: dogsBox.values.toList(),
                      favoriteDogs: widget.favoriteDogs,
                      onToggleFavorite: widget.onToggleFavorite,
                      currentUserId: userId,
                    ),
                  ),
                  (Route<dynamic> route) => false,
                );
                print('AuthPage - Navigation to PlaymatePage after verification triggered');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddDogPage(
                      onDogAdded: widget.onDogAdded,
                      favoriteDogs: widget.favoriteDogs,
                      onToggleFavorite: widget.onToggleFavorite,
                    ),
                  ),
                ).then((_) {
                  if (mounted && context.mounted) {
                    final updatedDogsBox = Hive.box<Dog>('dogsBox');
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaymatePage(
                          dogs: updatedDogsBox.values.toList(),
                          favoriteDogs: widget.favoriteDogs,
                          onToggleFavorite: widget.onToggleFavorite,
                          currentUserId: userId,
                        ),
                      ),
                      (Route<dynamic> route) => false,
                    );
                    print('AuthPage - Navigation to PlaymatePage after AddDogPage triggered');
                  }
                });
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
        setState(() {
          _isLoading = false;
        });
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
          );
        }
      }
    } else {
      print('AuthPage - Validation failed: All fields must be filled');
      setState(() {
        _isLoading = false;
      });
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseFillRequiredFields)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    print('AuthPage - Building UI (isLogin: $_isLogin) - Versioning');
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        print('GestureDetector - Screen tapped, keyboard dismissed');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink, Colors.pinkAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin ? l10n.signInTitle : l10n.signUpTitle,
                        style: GoogleFonts.dancingScript(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLogin) ...[
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: l10n.emailLabel,
                                  labelStyle: const TextStyle(color: Colors.white),
                                  prefixIcon: const Icon(Icons.email, color: Colors.white),
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.emailRequired;
                                  }
                                  final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                  if (!emailRegExp.hasMatch(value)) {
                                    return l10n.emailInvalid;
                                  }
                                  return null;
                                },
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  print('Email field tapped, keyboard dismissed');
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: l10n.usernameLabel,
                                  labelStyle: const TextStyle(color: Colors.white),
                                  prefixIcon: const Icon(Icons.person, color: Colors.white),
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.usernameRequired;
                                  }
                                  return null;
                                },
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  print('Username field tapped, keyboard dismissed');
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: l10n.emailLabel,
                                  labelStyle: const TextStyle(color: Colors.white),
                                  prefixIcon: const Icon(Icons.email, color: Colors.white),
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.emailRequired;
                                  }
                                  if (!value.contains('@')) {
                                    return l10n.emailInvalid;
                                  }
                                  return null;
                                },
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  print('Email field tapped, keyboard dismissed');
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedCountryCode,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                                  underline: const SizedBox(),
                                  isExpanded: true,
                                  dropdownColor: Colors.pinkAccent,
                                  items: countryCodes.map((country) {
                                    return DropdownMenuItem<String>(
                                      value: country['code']!,
                                      child: Text(
                                        '${country['name']} (${country['code']})',
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedCountryCode = value!;
                                        print('Country code changed to: $_selectedCountryCode');
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  FocusScope.of(context).requestFocus(_phoneFocusNode);
                                  SystemChannels.textInput.invokeMethod('TextInput.show');
                                  print('AuthPage - Phone TextField tapped');
                                  Scrollable.ensureVisible(context);
                                },
                                child: TextFormField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  decoration: InputDecoration(
                                    labelText: l10n.phoneLabel,
                                    labelStyle: const TextStyle(color: Colors.white),
                                    prefixIcon: const Icon(Icons.phone, color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.white24,
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n.phoneRequired;
                                    }
                                    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                                    print('AuthPage - Phone validation: $value, digits: $digits');
                                    if (digits.length < 10) {
                                      return l10n.phoneMinDigits;
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    print('AuthPage - Phone input: $value');
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: l10n.passwordLabel,
                                labelStyle: const TextStyle(color: Colors.white),
                                prefixIcon: const Icon(Icons.lock, color: Colors.white),
                                filled: true,
                                fillColor: Colors.white24,
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.white,
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
                              style: const TextStyle(color: Colors.white),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.passwordRequired;
                                }
                                final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');
                                if (!passwordRegex.hasMatch(value)) {
                                  return l10n.passwordValidation;
                                }
                                print('AuthPage - Password validation: $value, isValid: true');
                                return null;
                              },
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                print('Password field tapped, keyboard dismissed');
                              },
                            ),
                            const SizedBox(height: 10),
                            if (_isLogin) ...[
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                          print('AuthPage - Remember Me changed to: $_rememberMe');
                                        });
                                      }
                                    },
                                    checkColor: Colors.white,
                                    activeColor: Colors.pink,
                                  ),
                                  Text(
                                    l10n.rememberMeLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  child: Text(
                                    l10n.forgotPasswordLabel,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (!_isLogin) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: l10n.confirmPasswordLabel,
                                  labelStyle: const TextStyle(color: Colors.white),
                                  prefixIcon: const Icon(Icons.lock, color: Colors.white),
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (mounted) {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
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
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  print('Confirm Password field tapped, keyboard dismissed');
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      print('Checkbox clicked with value: $value');
                                      if (mounted) {
                                        setState(() {
                                          _agreeToTerms = value ?? false;
                                          print('AuthPage - Agree to Terms changed to: $_agreeToTerms');
                                        });
                                      }
                                    },
                                    checkColor: Colors.white,
                                    activeColor: Colors.pink,
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        print('TextButton clicked for Terms and Conditions');
                                        _openTermsPage();
                                      },
                                      child: Text.rich(
                                        TextSpan(
                                          text: l10n.termsAndConditionsLabel.split('Terms and Conditions')[0],
                                          style: const TextStyle(color: Colors.white),
                                          children: [
                                            const TextSpan(
                                              text: 'Terms and Conditions',
                                              style: TextStyle(
                                                color: Colors.white,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
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
                                          print('AuthPage - Receive News changed to: $_receiveNews');
                                        });
                                      }
                                    },
                                    checkColor: Colors.white,
                                    activeColor: Colors.pink,
                                  ),
                                  Text(
                                    l10n.receiveNewsLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                            ElevatedButton(
                              onPressed: (_isLogin || _agreeToTerms) && !_isLoading ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.pink,
                                minimumSize: const Size(double.infinity, 50),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.pink)
                                  : Text(
                                      _isLogin ? l10n.signInButton : l10n.signUpButton,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                if (mounted) {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _saveLoginState();
                                    print('Toggled login state to: $_isLogin');
                                  });
                                }
                              },
                              child: Text(
                                _isLogin ? l10n.noAccountSignUp : l10n.haveAccountSignIn,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final l10n = AppLocalizations.of(context)!;
                                final dogsBox = Hive.box<Dog>('dogsBox');
                                try {
                                  print('AuthPage - Continue as Guest pressed, dogsBox length: ${dogsBox.length}');
                                  if (dogsBox.isNotEmpty) {
                                    await Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlaymatePage(
                                          dogs: dogsBox.values.toList(),
                                          favoriteDogs: widget.favoriteDogs,
                                          onToggleFavorite: widget.onToggleFavorite,
                                          currentUserId: 'guest',
                                        ),
                                      ),
                                    );
                                    print('AuthPage - Navigation to PlaymatePage via guest mode triggered');
                                  } else {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddDogPage(
                                          onDogAdded: widget.onDogAdded,
                                          favoriteDogs: widget.favoriteDogs,
                                          onToggleFavorite: widget.onToggleFavorite,
                                        ),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      final updatedDogsBox = Hive.box<Dog>('dogsBox');
                                      print('AuthPage - AddDogPage returned true, updatedDogsBox length: ${updatedDogsBox.length}');
                                      if (updatedDogsBox.isNotEmpty) {
                                        await Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlaymatePage(
                                              dogs: updatedDogsBox.values.toList(),
                                              favoriteDogs: widget.favoriteDogs,
                                              onToggleFavorite: widget.onToggleFavorite,
                                              currentUserId: 'guest',
                                            ),
                                          ),
                                        );
                                        print('AuthPage - Navigation to PlaymatePage after adding dog triggered');
                                      } else {
                                        print('AuthPage - No dogs added after AddDogPage');
                                      }
                                    }
                                  }
                                } catch (e) {
                                  print('AuthPage - Error during guest navigation: $e');
                                  if (mounted && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                l10n.continueAsGuest,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}