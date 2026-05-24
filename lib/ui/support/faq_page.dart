import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {

    final faqItems = [

      _faq(
        "What is PetSupo?",
        "PetSupo is a platform that connects pet owners and helps them find suitable playmates, services, and resources for their pets.",
      ),

      _faq(
        "How can I find a playmate for my dog?",
        "Go to the Playmate section and use filters such as breed, age, and location to find suitable matches.",
      ),

      _faq(
        "Is PetSupo free to use?",
        "Basic features are free. Premium features may be available for enhanced visibility and additional benefits.",
      ),

      _faq(
        "Is it safe to meet other users?",
        "Users interact at their own responsibility. We recommend meeting in public places and taking necessary precautions.",
      ),

      _faq(
        "What should I do if I encounter a problem?",
        "You can report issues directly through the 'Report Problem' section in the app.",
      ),

      _faq(
        "How does location work?",
        "Location is used to show nearby pets, services, and matches. You can control location permissions from your device settings.",
      ),

      _faq(
        "How is my data protected?",
        "Your data is processed in accordance with applicable data protection laws, including KVKK. Please refer to our Privacy Policy for more details.",
      ),

      _faq(
        "Can I delete my account?",
        "Yes. You can request account deletion through the app or contact support for assistance.",
      ),
    ];

    return Container(
      color: const Color(0xFFFDF2F5),

      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            120,
          ),

          children: [

            // 🟣 HEADER
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9E1B4F),
                    Color(0xFFE91E63),
                  ],

                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                borderRadius:
                    BorderRadius.circular(28),

                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.pink.withOpacity(.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const Icon(
                   LucideIcons.helpCircle,
                    color: Color(0xFFFFC107),
                    size: 36,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "Frequently Asked Questions",
                    style: GoogleFonts.poppins(
                      color:
                          const Color(0xFFFFC107),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Find quick answers about PetSupo features, privacy, subscriptions, and safety.",
                    style: GoogleFonts.poppins(
                      color:
                          Colors.white.withOpacity(.92),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            ...faqItems.map((item) {

              return Container(
                margin:
                    const EdgeInsets.only(bottom: 16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(24),

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(
                        .04,
                      ),

                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor:
                        Colors.transparent,
                  ),

                  child: ExpansionTile(

                    tilePadding:
                        const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),

                    childrenPadding:
                        EdgeInsets.zero,

                    iconColor:
                        const Color(0xFF9E1B4F),

                    collapsedIconColor:
                        const Color(0xFF9E1B4F),

                    leading: Container(
                      width: 44,
                      height: 44,

                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF9E1B4F,
                        ).withOpacity(.10),

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: const Icon(
                        LucideIcons.helpCircle,
                        color:
                            Color(0xFF9E1B4F),
                        size: 22,
                      ),
                    ),

                    title: Text(
                      item.question,

                      style:
                          GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,

                        color: const Color(
                          0xFF9E1B4F,
                        ),
                      ),
                    ),

                    children: [

                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          22,
                        ),

                        child: Text(
                          item.answer,

                          style:
                              GoogleFonts.poppins(
                            fontSize: 13,
                            color:
                                Colors.black87,

                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  _FAQItem _faq(String q, String a) {

    return _FAQItem(
      question: q,
      answer: a,
    );
  }
}

class _FAQItem {

  final String question;
  final String answer;

  _FAQItem({
    required this.question,
    required this.answer,
  });
}