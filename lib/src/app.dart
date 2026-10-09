import 'live/account_favorites.dart';
import 'live/favorites_repository.dart';
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
  final FavoritesRepository Function(String)? favoritesFactory;
  const RochaPlusApp({super.key, this.authController, this.favoritesFactory});
  @override
  State<RochaPlusApp> createState() => _RochaPlusAppState();
}

class _RochaPlusAppState extends State<RochaPlusApp> {
  late final AuthController controller;
  bool introFinished = false;
  bool showingLayoutPreview = false;
  static const _previewBuild = bool.fromEnvironment('ROCHA_LAYOUT_PREVIEW');
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
              : AccountFavorites(key: ValueKey(controller.account!.uid),
            uid: controller.account!.uid, repositoryFactory: widget.favoritesFactory, builder: (favoritesRepository) =>
            HomeScreen(favoritesRepository: favoritesRepository, onSignOut: () async {
            await controller.signOut();
            if (controller.account != null) throw StateError('Sign-out failed');
          })),
    ));
  }
}
