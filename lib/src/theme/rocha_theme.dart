import 'package:flutter/material.dart';

class RochaColors {
  static const background = Color(0xFF05040A);
  static const surface = Color(0xFF0B1218);
  static const surfaceRaised = Color(0xFF101922);
  static const wine = Color(0xFF24113D);
  static const ruby = Color(0xFF16F34A);
  static const gold = Color(0xFFFFC43D);
  static const silver = Color(0xFFF2F2F4);
  static const muted = Color(0xFF9AA4AE);
  static const border = Color(0xFF243442);

  static const cosmicPurple = Color(0xFF5A20A8);
  static const cosmicBlue = Color(0xFF171A46);
  static const playGreen = Color(0xFF16F34A);
  static const playGreenSoft = Color(0x3316F34A);
  static const rock = Color(0xFF1B1A1E);
}

class RochaTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: RochaColors.background,
        colorScheme: const ColorScheme.dark(
          primary: RochaColors.playGreen,
          secondary: RochaColors.gold,
          surface: RochaColors.surface,
        ),
        cardTheme: CardThemeData(
          color: RochaColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: RochaColors.border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: RochaColors.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: RochaColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: RochaColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: RochaColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: RochaColors.playGreen,
              width: 2,
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: RochaColors.surface,
          indicatorColor: RochaColors.playGreenSoft,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}
