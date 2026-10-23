import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_repository.dart';
import '../theme/rocha_theme.dart';
import 'intro_screen.dart';

class LoginScreen extends StatelessWidget {
  final AuthController? controller;
  final VoidCallback? onPreviewLayout;
  const LoginScreen({super.key, this.controller, this.onPreviewLayout});

  @override
  Widget build(BuildContext context) {
    Widget content() => Scaffold(body: LayoutBuilder(builder: (context, constraints) {
      final tv = constraints.maxWidth >= 900;
      final google = controller?.supports(LoginProvider.google) == true;
      final apple = controller?.supports(LoginProvider.apple) == true;
      final busy = controller?.busy == true || controller?.initializing == true;
      final retry = controller != null && !controller!.ready && !busy;
      return Stack(fit: StackFit.expand, children: [
        if (tv) Image.asset('branding/home-tv-galaxy.png',
          key: const ValueKey('tv-login-background'), fit: BoxFit.cover),
        DecoratedBox(decoration: BoxDecoration(gradient: tv
          ? const LinearGradient(colors: [Color(0xED05040A), Color(0xCC130A25)])
          : const RadialGradient(center: Alignment.topCenter, radius: 1.2,
              colors: [RochaColors.wine, RochaColors.background]))),
        SafeArea(child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          child: FocusTraversalGroup(policy: OrderedTraversalPolicy(),
            child: SingleChildScrollView(child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tv ? 620 : 430),
                child: Padding(padding: EdgeInsets.all(tv ? 36 : 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const RochaLogo(fontSize: 58),
                    const SizedBox(height: 14),
                    Text(tv ? 'Entre no Rocha+ na sua TV' : 'Seu entretenimento em um só reino.',
                      key: tv ? const ValueKey('tv-login-title') : null,
                      style: TextStyle(color: Colors.white70, fontSize: tv ? 24 : 17),
                      textAlign: TextAlign.center),
                    SizedBox(height: tv ? 30 : 42),
                    FocusTraversalOrder(order: const NumericFocusOrder(1), child: _LoginButton(
                      key: const ValueKey('google-login-button'),
                      icon: Icons.g_mobiledata, label: 'Entrar com Google', tv: tv,
                      autofocus: tv && google,
                      onPressed: google && !busy
                        ? () => unawaited(controller!.signIn(LoginProvider.google)) : null)),
                    if (!tv || apple) ...[
                      const SizedBox(height: 14),
                      FocusTraversalOrder(order: const NumericFocusOrder(2), child: _LoginButton(
                        key: const ValueKey('apple-login-button'),
                        icon: Icons.apple, label: 'Entrar com Apple', tv: tv,
                        autofocus: tv && !google && apple,
                        onPressed: apple && !busy
                          ? () => unawaited(controller!.signIn(LoginProvider.apple)) : null)),
                    ],
                    if (tv) ...[
                      const SizedBox(height: 20),
                      const Text('Use as setas do controle para escolher e OK para entrar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RochaColors.silver, fontSize: 18)),
                      if (controller?.ready == true && !google && !apple)
                        const Padding(padding: EdgeInsets.only(top: 12), child: Text(
                          'Nenhuma opção de login está habilitada nesta versão.',
                          textAlign: TextAlign.center)),
                    ],
                    if (retry) ...[
                      const SizedBox(height: 18),
                      FocusTraversalOrder(order: const NumericFocusOrder(3), child: _LoginButton(
                        key: const ValueKey('retry-login-button'),
                        icon: Icons.refresh, label: 'Tentar login novamente', tv: tv,
                        autofocus: tv,
                        onPressed: () => unawaited(controller!.initialize()))),
                    ],
                    if (onPreviewLayout != null) ...[
                      const SizedBox(height: 20),
                      FocusTraversalOrder(order: const NumericFocusOrder(4),
                        child: OutlinedButton.icon(
                          key: const ValueKey('layout-preview-button'),
                          onPressed: onPreviewLayout, icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Visualizar layout de teste'))),
                      const SizedBox(height: 8),
                      const Text('Prévia visual, sem canais, player ou espelhamento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    if (busy) const CircularProgressIndicator(),
                    if (controller?.error != null) Semantics(liveRegion: true, child: Text(
                      controller!.error!, key: const ValueKey('login-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: tv ? 18 : 14))),
                    const SizedBox(height: 18),
                    Text('Entre na sua conta para acessar os canais.', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: tv ? 16 : 12)),
                  ])),
              )))),
          ),
        )),
      ]);
    }));
    return controller == null ? content() :
      AnimatedBuilder(animation: controller!, builder: (_, __) => content());
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool tv;
  final bool autofocus;
  const _LoginButton({super.key, required this.icon, required this.label,
    this.onPressed, this.tv = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: tv ? 76 : 56,
    child: FilledButton.tonalIcon(
      autofocus: autofocus, onPressed: onPressed,
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: tv ? 22 : 16)),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
          color: states.contains(WidgetState.focused) ? RochaColors.gold : Colors.transparent,
          width: 3)),
      ),
      icon: Icon(icon, size: tv ? 32 : 24), label: Text(label),
    ),
  );
}
