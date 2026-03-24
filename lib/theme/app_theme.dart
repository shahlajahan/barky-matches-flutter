import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─────────────────────────────
  // 🎨 Brand Colors
  // ─────────────────────────────
  static const Color bg = Color(0xFFFFF6F8);
  static const Color primary = Colors.pink;
  static const Color accent = Color(0xFFFFC107);
  static const Color card = Color(0xFF9E1B4F);

  static const Color textDark = Colors.black87;
  static const Color textLight = Colors.white;
  static const Color muted = Colors.black54;

  static const Color success = Colors.green;
  static const Color danger = Colors.red;

  // ─────────────────────────────
  // 📐 Radius
  // ─────────────────────────────
  static const double radius = 14;
  static const double radiusCard = 16;

  // ─────────────────────────────
  // 🌫 Shadow
  // ─────────────────────────────
  static List<BoxShadow> cardShadow({double opacity = 0.15}) => [
        BoxShadow(
          color: Colors.black.withOpacity(opacity),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

 // ─────────────────────────────
// 🔤 Text Styles (UPGRADED)
// ─────────────────────────────

static TextStyle h1({
  Color? color,
  FontWeight? weight,
  double? size,
}) =>
    GoogleFonts.poppins(
      fontSize: size ?? 20,
      fontWeight: weight ?? FontWeight.w700,
      color: color ?? textDark,
    );

static TextStyle h2({
  Color? color,
  FontWeight? weight,
  double? size,
}) =>
    GoogleFonts.poppins(
      fontSize: size ?? 18,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? textDark,
    );

static TextStyle h3({
  Color? color,
  FontWeight? weight,
  double? size,
}) =>
    GoogleFonts.poppins(
      fontSize: size ?? 16,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? textDark,
    );

static TextStyle body({
  Color? color,
  FontWeight? weight,
  double? size,
}) =>
    GoogleFonts.poppins(
      fontSize: size ?? 14,
      fontWeight: weight ?? FontWeight.w400,
      color: color ?? textDark,
    );

static TextStyle caption({
  Color? color,
  FontWeight? weight,
  double? size,
}) =>
    GoogleFonts.poppins(
      fontSize: size ?? 12,
      fontWeight: weight ?? FontWeight.w400,
      color: color ?? muted,
    );
  // ─────────────────────────────
  // 🎯 ThemeData (Correct Way)
  // ─────────────────────────────
  static ThemeData theme({Locale? locale}) {
    final isFa = locale?.languageCode == 'fa';

    return ThemeData(
      // ✅ fontFamily فقط اینجا
      fontFamily: isFa ? 'Vazirmatn' : 'Poppins',

      scaffoldBackgroundColor: bg,

      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        error: danger,
      ),

      textTheme: isFa
          ? const TextTheme()
          : GoogleFonts.poppinsTextTheme(),

      // ─────────────────────────
      // 🔝 AppBar
      // ─────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: h1(color: textLight),
        iconTheme: const IconThemeData(color: textLight),
      ),

      // ─────────────────────────
      // 🧱 Cards
      // ─────────────────────────
      cardTheme: CardThemeData(
  color: card,
  elevation: 0,
  margin: const EdgeInsets.symmetric(vertical: 8),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusCard),
  ),
),


      // ─────────────────────────
      // 🔘 Buttons
      // ─────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          textStyle: h2(color: Colors.black),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: h2(),
        ),
      ),

      // ─────────────────────────
      // ✏️ Inputs
      // ─────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),

      // ─────────────────────────
      // ⬇️ Bottom Navigation
      // ─────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.pink,
        selectedItemColor: Color(0xFFFFC107),
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),

      // ─────────────────────────
      // ➕ FAB
      // ─────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),

      // ─────────────────────────
      // ➖ Divider
      // ─────────────────────────
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
