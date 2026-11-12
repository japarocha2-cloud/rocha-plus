import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/firebase_auth_repository.dart';
import '../screens/live_tv_screen.dart';
import '../screens/login_screen.dart';
import '../theme/rocha_theme.dart';
import 'approved_catalog_repository.dart';
import 'lab_access_gate.dart';
import 'lab_entitlement.dart';

class FunctionalLabApp extends StatefulWidget {
  final AuthController? authController;
  final LabVerifier verify;
  final WidgetBuilder? homeBuilder;
  const FunctionalLabApp(
      {super.key,
      this.authController,
      this.verify = LabEntitlement.check,
      this.homeBuilder});
  @override
  State<FunctionalLabApp> createState() => _FunctionalLabAppState();
}

class _FunctionalLabAppState extends State<FunctionalLabApp> {
  late final AuthController _auth = widget.authController ??
      AuthController(FirebaseAuthRepository(requireHomologation: true));
  late final _catalog = ApprovedCatalogRepository();
  @override
  void initState() {
    super.initState();
    if (_auth.initializing) unawaited(_auth.initialize());
  }

  @override
  void dispose() {
    if (widget.authController == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _auth,
      builder: (_, __) => MaterialApp(
            key: ValueKey(_auth.account?.uid ?? 'signed-out'),
            title: 'Rocha+ LAB',
            theme: RochaTheme.dark,
            debugShowCheckedModeBanner: false,
            home: _auth.initializing
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()))
                : _auth.account == null
                    ? LoginScreen(controller: _auth)
                    : LabAccessGate(
                        uid: _auth.account!.uid,
                        verify: widget.verify,
                        onSignOut: () => unawaited(_auth.signOut()),
                        homeBuilder: widget.homeBuilder ??
                            (_) => LiveTvScreen(
                                repository: _catalog, onSignOut: _auth.signOut),
                      ),
          ));
}
