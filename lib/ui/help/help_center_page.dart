import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:info@petsupo.com?subject=PetSupo Support');

    await launchUrl(uri);
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,

              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F).withOpacity(.10),

                borderRadius: BorderRadius.circular(18),
              ),

              child: Icon(icon, color: const Color(0xFF9E1B4F), size: 28),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaq({required String question, required String answer}) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool expanded = false;

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(22),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.04),

                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(22),

                    onTap: () {
                      setInnerState(() {
                        expanded = !expanded;
                      });
                    },

                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,

                            decoration: BoxDecoration(
                              color: const Color(0xFF9E1B4F).withOpacity(.10),

                              borderRadius: BorderRadius.circular(14),
                            ),

                            child: const Icon(
                              LucideIcons.helpCircle,
                              color: Color(0xFF9E1B4F),
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              question,

                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,

                                color: const Color(0xFF9E1B4F),
                              ),
                            ),
                          ),

                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,

                            duration: const Duration(milliseconds: 220),

                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF9E1B4F),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),

                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),

                      child: Text(
                        answer,

                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),

                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,

                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // 🟣 HEADER
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9E1B4F), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius: BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Icon(
                      LucideIcons.lifeBuoy,
                      color: Color(0xFFFFC107),
                      size: 36,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "Help Center",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFC107),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Need help with PetSupo? Find answers and contact support easily.",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.92),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildCard(
                icon: LucideIcons.mail,
                title: "Email Support",
                subtitle: "Contact our support team directly.",

                onTap: _openEmail,
              ),

              _buildCard(
                icon: LucideIcons.globe,
                title: "Visit Website",
                subtitle: "Open the official PetSupo website.",

                onTap: () {
                  _openUrl("https://www.petsupo.com");
                },
              ),

              _buildCard(
                icon: LucideIcons.instagram,
                title: "Instagram",
                subtitle: "Follow PetSupo for updates and news.",

                onTap: () {
                  _openUrl("https://instagram.com/petsupo.app");
                },
              ),

              const SizedBox(height: 12),

              Text(
                "Frequently Asked Questions",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9E1B4F),
                ),
              ),

              const SizedBox(height: 18),

              _buildFaq(
                question: "How do I create a playdate?",
                answer:
                    "Go to the Playdate section, choose a park, select a date and time, and send a request.",
              ),

              _buildFaq(
                question: "How do subscriptions work?",
                answer:
                    "Premium and Gold subscriptions unlock advanced features such as boosted visibility and business tools.",
              ),

              _buildFaq(
                question: "How can I register my business?",
                answer:
                    "Gold users can apply for business registration from the Profile section.",
              ),

              _buildFaq(
                question: "How can I report a problem?",
                answer:
                    "Use the Report Problem section in your profile to contact support.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
