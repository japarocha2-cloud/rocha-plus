import 'dart:async';
import 'package:flutter/material.dart';
import 'auth/auth_controller.dart';
import 'auth/firebase_auth_repository.dart';
import 'auth/subscription_access.dart';
import 'app_release_policy.dart';
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
              : !RochaReleasePolicy.paidSubscriptionRequired
                  ? HomeScreen(onSignOut: () async {
                      await controller.signOut();
                      if (controller.account != null) throw StateError('Sign-out failed');
                    })
                  : _SubscriptionGate(uid: controller.account!.uid, onSignOut: () async {
            await controller.signOut();
            if (controller.account != null) throw StateError('Sign-out failed');
          }),
    ));
  }
}

class _SubscriptionGate extends StatefulWidget {
  final String uid;
  final Future<void> Function() onSignOut;
  const _SubscriptionGate({required this.uid, required this.onSignOut});

  @override
  State<_SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<_SubscriptionGate> {
  late Future<bool> _allowed;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _allowed = SubscriptionAccess.isAllowed(widget.uid);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SubscriptionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) {
      if (snapshot.data == true) {
        return HomeScreen(onSignOut: widget.onSignOut);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Rocha+ • Assinatura')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 52),
              const SizedBox(height: 18),
              Text(snapshot.connectionState == ConnectionState.waiting
                  ? 'Verificando sua assinatura...'
                  : 'Acesso não liberado. Confira sua assinatura ou aguarde a confirmação do pagamento.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _refresh, child: const Text('Verificar novamente')),
              TextButton(onPressed: widget.onSignOut, child: const Text('Sair da conta')),
            ]),
          ),
        ),
      );
    },
  );
}
