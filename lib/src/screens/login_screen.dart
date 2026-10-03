import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';
import 'home_screen.dart';
import 'intro_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enter(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [RochaColors.wine, RochaColors.background],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
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
                    label: 'Continuar com Google',
                    onPressed: () => _enter(context),
                  ),
                  const SizedBox(height: 14),
                  _LoginButton(
                    icon: Icons.apple,
                    label: 'Continuar com Apple',
                    onPressed: () => _enter(context),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => _enter(context),
                    child: const Text('Explorar canais gratuitos'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Google e Apple serão conectados às credenciais oficiais antes da publicação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
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
