import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../models/found_dog.dart';
import '../../app_state.dart';

class FoundDogDetailPage extends StatelessWidget {
  final FoundDog foundDog;

  const FoundDogDetailPage({
    super.key,
    required this.foundDog,
  });

  @override
  Widget build(BuildContext context) {
    final isClaimed = foundDog.isClaimed;

    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFFFF6F8),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// 🔙 BACK HEADER (مثل Lost دقیق)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF9E1B4F),
                  onPressed: () {
                    context.read<AppState>().closeFoundDogDetail();
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  "Found Dog Details",
                  style: AppTheme.h2(),
                ),
              ],
            ),

            const SizedBox(height: 8),

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

                    /// 🐾 IMAGE OR PAW (همان سایز icon)
                    GestureDetector(
                      onTap: foundDog.imageUrl != null &&
                              foundDog.imageUrl!.isNotEmpty
                          ? () {
                              _showFullImage(context, foundDog.imageUrl!);
                            }
                          : null,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: foundDog.imageUrl == null ||
                                  foundDog.imageUrl!.isEmpty
                              ? LinearGradient(
                                  colors: isClaimed
                                      ? [Colors.greenAccent, Colors.teal]
                                      : [
                                          Colors.orangeAccent,
                                          Colors.deepOrange
                                        ],
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: foundDog.imageUrl != null &&
                                  foundDog.imageUrl!.isNotEmpty
                              ? Image.network(
                                  foundDog.imageUrl!,
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
                      foundDog.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      foundDog.breed,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// 💛 Emotional sentence (مثل Accept card)
                    Text(
                      isClaimed
                          ? "Reunited and safe again 💛🐾"
                          : "Help this pup find their home 🏡🐶",
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
                        _infoChip("Color", foundDog.color),
                        if (foundDog.weight != null)
                          _infoChip("Weight", "${foundDog.weight} kg"),
                        _infoChip("Collar", foundDog.collarType),
                        _infoChip("Clothing", foundDog.clothingColor),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _infoText("Found Location: ${foundDog.foundLocation}"),

                    const SizedBox(height: 8),

                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                          "https://www.google.com/maps/search/?api=1&query=${foundDog.latitude},${foundDog.longitude}",
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

                    const SizedBox(height: 14),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final contact = foundDog.contactInfo;
                        final type = contact["type"];
                        final value = contact["value"];

                        if (type == "Phone") {
                          final uri = Uri.parse("tel:$value");
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }

                        if (type == "Email") {
                          final uri = Uri.parse("mailto:$value");
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }

                        if (type == "Instagram") {
                          final uri =
                              Uri.parse("https://instagram.com/$value");
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(180, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon:
                          const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text(
                        "Contact Reporter",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      isClaimed ? "Dog Claimed 🐾" : "Not Claimed",
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

  /// 🔥 Fullscreen image viewer
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
        style:
            GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
      ),
    );
  }
}