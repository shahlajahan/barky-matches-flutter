import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.pink[400],
      ),
      body: Container(
        color: Colors.grey[200], // جایگزینی گرادیانت با رنگ ساده
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms and Conditions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Last updated: May 09, 2025',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Introduction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome to Doggy Playdate! By signing up, you agree to these Terms and Conditions. This app is designed to help you find playmates for your dogs, connect with other pet owners, and access pet-related services. These terms govern your use of the app and services provided by Doggy Playdate.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. User Responsibilities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '- You must be at least 13 years old to use this app.\n'
                '- You are responsible for maintaining the confidentiality of your account and password.\n'
                '- You agree not to use the app for any unlawful or prohibited activities.\n'
                '- You must provide accurate and up-to-date information during registration.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Data Collection and Privacy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We collect personal data such as your username, email, location, and pet information to provide our services. In accordance with the Turkish Personal Data Protection Law (KVKK No. 6698) and international laws (e.g., GDPR), we:\n'
                '- Obtain explicit consent before collecting or processing your data.\n'
                '- Use your data only for the purposes stated (e.g., finding playmates, providing location-based services).\n'
                '- Implement security measures to protect your data.\n'
                '- Allow you to access, correct, or delete your data upon request. To exercise your rights, contact us at support@doggyplaydate.com.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '4. User Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '- You retain ownership of any content you upload (e.g., photos, descriptions).\n'
                '- By uploading content, you grant Doggy Playdate a non-exclusive, royalty-free license to use, display, and distribute your content within the app.\n'
                '- You must not upload content that is illegal, offensive, or violates the rights of others.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '5. Limitation of Liability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Doggy Playdate is not liable for any damages arising from your use of the app, including but not limited to interactions with other users or pets. We do not guarantee the accuracy of information provided by other users.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '6. Governing Law',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These Terms and Conditions are governed by the laws of the Republic of Turkey. Any disputes arising from your use of the app will be resolved in the courts of Istanbul, Turkey, unless otherwise required by international law (e.g., GDPR for EU users).',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '7. Changes to Terms',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We may update these Terms and Conditions from time to time. You will be notified of significant changes via email or in-app notifications. Continued use of the app after changes constitutes your acceptance of the new terms.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '8. Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If you have any questions or concerns about these Terms and Conditions, please contact us at support@doggyplaydate.com.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}