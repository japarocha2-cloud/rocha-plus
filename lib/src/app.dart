import 'billing/billing_repository.dart';
import 'billing/subscription_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth/auth_controller.dart';
import 'auth/firebase_auth_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/visual_trial_test_screen.dart';
import 'theme/rocha_theme.dart';

class RochaPlusApp extends StatefulWidget {
  final AuthController? authController;
  final BillingRepository? billingRepository;
  const RochaPlusApp({super.key, this.authController, this.billingRepository});
  @override
  State<RochaPlusApp> createState() => _RochaPlusAppState();
}

class _RochaPlusAppState extends State<RochaPlusApp> {
  late final AuthController controller;
  bool introFinished = false;
  bool showingLayoutPreview = false;
  static const _previewBuild = bool.fromEnvironment('ROCHA_LAYOUT_PREVIEW');
  static const _visualTestBuild = bool.fromEnvironment('ROCHA_VISUAL_TEST');
  bool get _mayPreview => _previewBuild && !FirebaseAuthRepository.isConfigured;
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
    if (_visualTestBuild) {
      return MaterialApp(
        title: 'Rocha+ Visual Test',
        debugShowCheckedModeBanner: false,
        theme: RochaTheme.dark,
        home: const VisualTrialTestScreen(),
      );
    }
    return AnimatedBuilder(animation: controller, builder: (_, __) => MaterialApp(
      // Clear every nested channel/player route when the session changes.
      key: ValueKey(controller.account?.uid ??
          (showingLayoutPreview ? 'layout-preview' : 'signed-out')),
      title: 'Rocha+',
      debugShowCheckedModeBanner: false,
      theme: RochaTheme.dark,
      home: !introFinished ? IntroScreen(onFinished: () => setState(() => introFinished = true)) :
          controller.initializing ? const Scaffold(body: Center(child: CircularProgressIndicator())) :
          controller.account == null
              ? showingLayoutPreview && _mayPreview
                  ? HomeScreen(previewOnly: true, onSignOut: () async {
                      setState(() => showingLayoutPreview = false);
                    })
                  : LoginScreen(controller: controller,
                      onPreviewLayout: _mayPreview
                          ? () => setState(() => showingLayoutPreview = true)
                          : null)
              : controller.account!.isAdmin
              ? AdminHomeScreen(onSignOut: () => controller.signOut())
              : SubscriptionGate(key: ValueKey(controller.account!.uid), uid: controller.account!.uid, repository: widget.billingRepository, onSignOut: () async {
            await controller.signOut();
            if (controller.account != null) throw StateError('Sign-out failed');
          }),
    ));
  }
}
