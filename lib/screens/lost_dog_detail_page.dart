import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../theme/app_theme.dart';
import '../models/lost_dog.dart';

class LostDogDetailPage extends StatelessWidget {
  final LostDog lostDog;

  const LostDogDetailPage({
    super.key,
    required this.lostDog,
  });

  @override
  Widget build(BuildContext context) {
    final isFound = lostDog.isFound;

    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFFFF6F8),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// 🔙 Back Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF9E1B4F),
                  onPressed: () {
                    context.read<AppState>().closeLostDogDetail();
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  "Lost Dog Details",
                  style: AppTheme.h2(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: const Color(0xFF9E1B4F),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// 🐾 IMAGE OR PAW (دایره 56)
                    GestureDetector(
                      onTap: lostDog.imageUrl != null &&
                              lostDog.imageUrl!.isNotEmpty
                          ? () {
                              _showFullImage(context, lostDog.imageUrl!);
                            }
                          : null,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: lostDog.imageUrl == null ||
                                  lostDog.imageUrl!.isEmpty
                              ? LinearGradient(
                                  colors: isFound
                                      ? [Colors.greenAccent, Colors.teal]
                                      : [
                                          Colors.orangeAccent,
                                          Colors.deepOrange
                                        ],
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: lostDog.imageUrl != null &&
                                  lostDog.imageUrl!.isNotEmpty
                              ? Image.network(
                                  lostDog.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.pets,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      lostDog.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      lostDog.breed,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// 💛 Emotional line
                    Text(
                      isFound
                          ? "Reunited and safe again 💛🐾"
                          : "Help bring this furry friend back home 🏡🐶",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _infoChip("Gender", lostDog.gender),
                        _infoChip("Health", lostDog.healthStatus),
                        _infoChip("Color", lostDog.color),
                        if (lostDog.weight != null)
                          _infoChip("Weight", "${lostDog.weight} kg"),
                        _infoChip("Collar", lostDog.collarType),
                        _infoChip("Clothing", lostDog.clothingColor),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _infoText("Location: Near reported area"),

                    const SizedBox(height: 8),

                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                          "https://www.google.com/maps/search/?api=1&query=${lostDog.latitude},${lostDog.longitude}",
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.location_on, size: 16),
                      label: const Text("View on Map"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      isFound ? "Dog Found 🐾" : "Still Missing",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $value",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
      ),
    );
  }

  Widget _infoText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}