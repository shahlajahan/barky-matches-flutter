import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class VetPage extends StatefulWidget {
  const VetPage({super.key});

  @override
  _VetPageState createState() => _VetPageState();
}

class _VetPageState extends State<VetPage> {
  Position? _currentPosition;
  bool _isLoading = true;

  // لیست کامل‌تر دامپزشک‌ها
  final List<Map<String, dynamic>> _vets = [
    {
      'name': 'Dr. Ayşe Yılmaz',
      'specialty': 'General Vet',
      'latitude': 41.0082,
      'longitude': 28.9784,
      'phone': '+905551234567',
      'address': 'Kadiköy, İstanbul',
    },
    {
      'name': 'Dr. Mehmet Özkan',
      'specialty': 'Surgeon',
      'latitude': 41.0137,
      'longitude': 28.9815,
      'phone': '+905551234568',
      'address': 'Sultanahmet, İstanbul',
    },
    {
      'name': 'Dr. Elif Kaya',
      'specialty': 'Dermatologist',
      'latitude': 41.0425,
      'longitude': 28.9941,
      'phone': '+905551234569',
      'address': 'Şişli, İstanbul',
    },
    {
      'name': 'Dr. Burak Şahin',
      'specialty': 'General Vet',
      'latitude': 40.9707,
      'longitude': 29.0359,
      'phone': '+905551234570',
      'address': 'Fenerbahçe, İstanbul',
    },
    {
      'name': 'Dr. Selin Demir',
      'specialty': 'Nutritionist',
      'latitude': 41.1058,
      'longitude': 29.0557,
      'phone': '+905551234571',
      'address': 'Sarıyer, İstanbul',
    },
    {
      'name': 'Dr. Can Ekinci',
      'specialty': 'Orthopedist',
      'latitude': 41.1833,
      'longitude': 28.9833,
      'phone': '+905551234572',
      'address': 'Belgrad Ormanı, İstanbul',
    },
    {
      'name': 'Dr. Zeynep Arslan',
      'specialty': 'General Vet',
      'latitude': 40.9667,
      'longitude': 29.0667,
      'phone': '+905551234573',
      'address': 'Caddebostan, İstanbul',
    },
    {
      'name': 'Dr. Kaan Mert',
      'specialty': 'Dentist',
      'latitude': 40.9833,
      'longitude': 28.8167,
      'phone': '+905551234574',
      'address': 'Bakırköy, İstanbul',
    },
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // درخواست مجوز موقعیت مکانی
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        print('VetPage - Location permission denied');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to show nearby vets.'),
          ),
        );
        return;
      }
    }

    // درخواست مجوز دسترسی به موقعیت در پس‌زمینه (برای Android 10 و بالاتر)
    var backgroundStatus = await Permission.locationAlways.status;
    if (!backgroundStatus.isGranted) {
      backgroundStatus = await Permission.locationAlways.request();
      if (!backgroundStatus.isGranted) {
        print('VetPage - Background location permission denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background location permission is recommended for better navigation.'),
          ),
        );
        // همچنان ادامه می‌دهیم، چون دسترسی پس‌زمینه اجباری نیست
      }
    }

    // بعد از گرفتن مجوزها، موقعیت فعلی رو دریافت می‌کنیم
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('VetPage - Location services are disabled.');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services to continue.'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('VetPage - Location permissions are denied.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        print('VetPage - Location permissions are permanently denied.');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them from settings.'),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        print('VetPage - Location acquired: Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      });
    } catch (e) {
      print('VetPage - Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000; // تبدیل به کیلومتر
  }

  Future<void> _connectToVet(String vetName, String phone) async {
    // نمایش SnackBar برای اطلاع‌رسانی
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to $vetName...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // باز کردن برنامه تلفن
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        print('VetPage - Opening phone app with number: $phone');
        // نمایش SnackBar برای موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $vetName! Calling: $phone'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        print('VetPage - Could not launch phone app for number: $phone');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone app'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('VetPage - Error launching phone app: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to $vetName: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink, Colors.pinkAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Visit Vet',
          style: GoogleFonts.dancingScript(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink, Colors.pinkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading vets...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _currentPosition == null
                  ? const Center(
                      child: Text(
                        'Unable to get location. Please enable location services.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _vets.length,
                      itemBuilder: (context, index) {
                        final vet = _vets[index];
                        final distance = _calculateDistance(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          vet['latitude'],
                          vet['longitude'],
                        ).toStringAsFixed(2);

                        return Card(
                          color: Colors.white.withOpacity(0.9),
                          child: ListTile(
                            title: Text(
                              vet['name'],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Specialty: ${vet['specialty']}\nDistance: $distance km\nAddress: ${vet['address']}\nPhone: ${vet['phone']}',
                              style: GoogleFonts.poppins(),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                _connectToVet(vet['name'], vet['phone']);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                'Connect',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}