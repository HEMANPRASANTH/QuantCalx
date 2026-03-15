import 'package:flutter/material.dart';

// ─── COLOURS ──────────────────────────────────────────────────────────────────
// Sea blue accent used in both modes
const kSeaBlue = Color(0xFF0097A7);  // Cyan-700 / sea blue

// DARK (AMOLED)
const kDarkBg      = Color(0xFF000000); // True AMOLED black
const kDarkSurface = Color(0xFF0A0E14);
const kDarkCard    = Color(0xFF0D1520);
const kDarkText    = Colors.white;
const kDarkSubText = Color(0xFFB0BEC5);
const kOnSeaBlue   = Colors.black;   // text ON sea-blue in dark

// LIGHT
const kLightBg      = Color(0xFFF4F6F9);
const kLightSurface = Colors.white;
const kLightCard    = Colors.white;
const kLightText    = Color(0xFF0D1520);
const kLightSubText = Color(0xFF546E7A);
const kOnSeaBlueLight = Colors.white; // text ON sea-blue in light

// ─── THEME BUILDER ────────────────────────────────────────────────────────────
ThemeData buildTheme({required bool dark}) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  final bg      = dark ? kDarkBg      : kLightBg;
  final surface = dark ? kDarkSurface : kLightSurface;
  final card    = dark ? kDarkCard    : kLightCard;
  final text    = dark ? kDarkText    : kLightText;
  final sub     = dark ? kDarkSubText : kLightSubText;

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: kSeaBlue,
      onPrimary: dark ? kOnSeaBlue : kOnSeaBlueLight,
      secondary: kSeaBlue,
      onSecondary: dark ? kOnSeaBlue : kOnSeaBlueLight,
      surface: surface,
      onSurface: text,
      error: Colors.red,
      onError: Colors.white,
    ),
    cardColor: card,
    dividerColor: dark ? Colors.white10 : Colors.black12,
    textTheme: base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      hintStyle: TextStyle(color: sub.withValues(alpha: 0.6)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kSeaBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      iconTheme: IconThemeData(color: text),
      titleTextStyle: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}
