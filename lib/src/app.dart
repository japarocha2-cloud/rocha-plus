import 'dart:async';
import 'package:flutter/material.dart';
import 'auth/auth_controller.dart';
import 'auth/firebase_auth_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/intro_screen.dart';
import 'theme/rocha_theme.dart';

class RochaPlusApp extends StatefulWidget {
  final AuthController? authController;
  const RochaPlusApp({super.key, this.authController});
  @override
  State<RochaPlusApp> createState() => _RochaPlusAppState();
}

class _RochaPlusAppState extends State<RochaPlusApp> {
  late final AuthController controller;
  bool introFinished = false;
  @override
  void initState() {
    super.initState();
    controller = widget.authController ?? AuthController(FirebaseAuthRepository());
    if (controller.initializing) unawaited(controller.initialize());
  }
  @override
  void dispose() {
    if (widget.authController == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (_, __) => MaterialApp(
      // Clear every nested channel/player route when the session changes.
      key: ValueKey(controller.account?.uid ?? 'signed-out'),
      title: 'Rocha+',
      debugShowCheckedModeBanner: false,
      theme: RochaTheme.dark,
      home: !introFinished ? IntroScreen(onFinished: () => setState(() => introFinished = true)) :
          controller.initializing ? const Scaffold(body: Center(child: CircularProgressIndicator())) :
          controller.account == null ? LoginScreen(controller: controller) :
          HomeScreen(onSignOut: () async {
            await controller.signOut();
            if (controller.account != null) throw StateError('Sign-out failed');
          }),
    ));
  }
}
