import 'package:flutter/material.dart';

class RochaColors {
  static const background = Color(0xFF070707);
  static const surface = Color(0xFF141414);
  static const wine = Color(0xFF35070D);
  static const ruby = Color(0xFFD10A17);
  static const gold = Color(0xFFD4AF37);
  static const silver = Color(0xFFE9E9E9);
}

class RochaTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: RochaColors.background,
        colorScheme: const ColorScheme.dark(
          primary: RochaColors.ruby,
          secondary: RochaColors.gold,
          surface: RochaColors.surface,
        ),
        cardTheme: const CardThemeData(
          color: RochaColors.surface,
          elevation: 0,
        ),
      );
}
