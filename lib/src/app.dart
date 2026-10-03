import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';
import 'theme/rocha_theme.dart';

class RochaPlusApp extends StatelessWidget {
  const RochaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rocha+',
      debugShowCheckedModeBanner: false,
      theme: RochaTheme.dark,
      home: const IntroScreen(),
    );
  }
}
