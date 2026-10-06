import 'package:flutter/material.dart';

import 'models/audit.dart';
import 'models/lead.dart';

/// FansConnector outreach palette: navy, cream and gold.
class Brand {
  static const navy = Color(0xFF0F1B2D);
  static const navyPanel = Color(0xFF17263B);
  static const navyLine = Color(0xFF2A3B55);
  static const cream = Color(0xFFF4EFE6);
  static const creamLine = Color(0xFFD9D1C2);
  static const creamRow = Color(0xFFE3DCCF);
  static const gold = Color(0xFFF2B33D);
  static const goldDark = Color(0xFF8A5A00);
  static const ink = Color(0xFF3B4552);
  static const muted = Color(0xFF55606E);
  static const mist = Color(0xFFC9D1DC);
  static const white = Color(0xFFFFFFFF);

  /// Accent colours the graphic can use (Settings → Graphic colour).
  static const accents = <Color>[
    Color(0xFFF2B33D),
    Color(0xFF5FD3A6),
    Color(0xFFFF7A59),
    Color(0xFF8FB8FF),
  ];
  static const accentNames = ['Gold', 'Mint', 'Coral', 'Sky'];

  static Color accent(int i) => accents[i.clamp(0, accents.length - 1)];

  static const display = 'Bricolage';
  static const body = 'Instrument';

  /// Pill background for each audit status.
  static Color pillBg(AuditStatus s) => switch (s) {
        AuditStatus.good => const Color(0xFFD7EBDA),
        AuditStatus.warn => const Color(0xFFFBE4C2),
        AuditStatus.bad => const Color(0xFFF6D2C9),
      };

  /// Pill text for each audit status. Darker than the fill for contrast.
  static Color pillFg(AuditStatus s) => switch (s) {
        AuditStatus.good => const Color(0xFF1D5230),
        AuditStatus.warn => const Color(0xFF7A4300),
        AuditStatus.bad => const Color(0xFF8A2412),
      };
}

/// Colour for each pipeline status (dots and chips).
Color statusColor(LeadStatus s) => switch (s) {
      LeadStatus.newLead => const Color(0xFF8FA3BF),
      LeadStatus.contacted => const Color(0xFF3D7BD9),
      LeadStatus.replied => const Color(0xFFC9861A),
      LeadStatus.interested => const Color(0xFF8E5BD0),
      LeadStatus.won => const Color(0xFF2E8B57),
      LeadStatus.lost => const Color(0xFFB4532F),
    };

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Brand.navy,
    onPrimary: Brand.cream,
    secondary: Brand.gold,
    onSecondary: Brand.navy,
    error: Color(0xFF8A2412),
    onError: Brand.white,
    surface: Brand.cream,
    onSurface: Brand.navy,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Brand.body,
    scaffoldBackgroundColor: Brand.cream,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.cream,
      foregroundColor: Brand.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: Brand.display,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: Brand.navy,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Brand.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Brand.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Brand.creamLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Brand.creamLine),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Brand.white,
      indicatorColor: Brand.gold,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Brand.navy,
        side: const BorderSide(color: Brand.navy, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    ),
  );
}
