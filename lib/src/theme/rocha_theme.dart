import 'package:flutter/material.dart';

class RochaColors {
  // Nova identidade Rocha+: rocha escura + ouro + Play verde + atmosfera cósmica.
  static const background = Color(0xFF05040A);
  static const surface = Color(0xFF111018);
  static const wine = Color(0xFF24113D);
  // Compatibilidade temporária com widgets antigos. Não usar como cor geral.
  static const ruby = cosmicPurple;
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
          primary: RochaColors.cosmicPurple,
          secondary: RochaColors.gold,
          surface: RochaColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFF0C1018),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF332A42))),
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
          foregroundColor: RochaColors.silver)),
        chipTheme: const ChipThemeData(
          labelStyle: TextStyle(color: RochaColors.silver),
          secondaryLabelStyle: TextStyle(color: RochaColors.gold),
          checkmarkColor: RochaColors.gold,
          selectedColor: RochaColors.wine,
        ),
        cardTheme: const CardThemeData(
          color: RochaColors.surface,
          elevation: 0,
        ),
      );
}
