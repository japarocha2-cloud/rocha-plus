import 'dart:async';
import 'package:flutter/material.dart';
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
    Widget content() => Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [RochaColors.wine, RochaColors.background],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) =>
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const RochaLogo(fontSize: 58),
                  const SizedBox(height: 14),
                  const Text(
                    'Seu entretenimento em um só reino.',
                    style: TextStyle(color: Colors.white70, fontSize: 17),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 42),
                  _LoginButton(
                    icon: Icons.g_mobiledata,
                    label: 'Entrar com Google',
                    onPressed: controller?.supports(LoginProvider.google) == true && !controller!.busy
                        ? () => unawaited(controller!.signIn(LoginProvider.google)) : null,
                  ),
                  const SizedBox(height: 14),
                  const _LoginButton(
                    icon: Icons.apple,
                    label: 'Entrar com Apple',
                  ),
                  const SizedBox(height: 4),
                  const Text('Em breve', style: TextStyle(
                    fontSize: 11, color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const ValueKey('admin-login-entry'),
                    onPressed: controller?.ready == true && controller?.busy == false
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => _AdminLoginDialog(controller: controller!),
                        ) : null,
                    child: const Text('Acesso administrativo',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ),
                  if (onPreviewLayout != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      key: const ValueKey('layout-preview-button'),
                      onPressed: onPreviewLayout,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Visualizar layout de teste'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Prévia visual, sem canais, player ou espelhamento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  const SizedBox(height: 18),
                  if (controller?.busy == true) const CircularProgressIndicator(),
                  if (controller?.error != null)
                    Text(controller!.error!, key: const ValueKey('login-error'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 18),
                  const Text(
                    'Entre na sua conta para acessar os canais.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return controller == null ? content() :
        AnimatedBuilder(animation: controller!, builder: (_, __) => content());
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _LoginButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _AdminLoginDialog extends StatefulWidget {
  final AuthController controller;
  const _AdminLoginDialog({required this.controller});
  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}
class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Acesso ADM Rocha+'),
    content: SizedBox(width: 360, child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
          autocorrect: false, decoration: const InputDecoration(labelText: 'E-mail')),
        TextField(controller: password, obscureText: true, autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Senha')),
        AnimatedBuilder(animation: widget.controller, builder: (_, __) =>
          widget.controller.error == null ? const SizedBox.shrink() :
          Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(widget.controller.error!, style:
              const TextStyle(color: Colors.redAccent, fontSize: 12)))),
      ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: widget.controller.busy ? null : () async {
        await widget.controller.signInAdmin(email.text, password.text);
        if (context.mounted && widget.controller.account?.isAdmin == true) {
          Navigator.of(context).pop();
        }
      }, child: const Text('Entrar')),
    ],
  );
}
