import 'package:flutter/material.dart';

class RochaColors {
  // Nova identidade Rocha+: rocha escura + ouro + Play verde + atmosfera cósmica.
  static const background = Color(0xFF05040A);
  static const surface = Color(0xFF111018);
  static const wine = Color(0xFF24113D);
  static const ruby = Color(0xFF16F34A);
  static const gold = Color(0xFFFFC43D);
  static const silver = Color(0xFFF2F2F4);

  static const cosmicPurple = Color(0xFF5A20A8);
  static const cosmicBlue = Color(0xFF171A46);
  static const playGreen = Color(0xFF16F34A);
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
        cardTheme: const CardThemeData(
          color: RochaColors.surface,
          elevation: 0,
        ),
      );
}
