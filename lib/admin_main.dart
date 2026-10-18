import 'package:flutter/material.dart';
import 'src/auth/auth_controller.dart';
import 'src/auth/firebase_auth_repository.dart';
import 'src/screens/admin_trial_test_screen.dart';
import 'src/theme/rocha_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RochaAdminTestApp());
}
class RochaAdminTestApp extends StatefulWidget {
  const RochaAdminTestApp({super.key});
  @override
  State<RochaAdminTestApp> createState() => _RochaAdminTestAppState();
}
class _RochaAdminTestAppState extends State<RochaAdminTestApp> {
  late final AuthController controller;
  @override
  void initState() {
    super.initState();
    controller = AuthController(FirebaseAuthRepository());
    controller.initialize();
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => MaterialApp(
      title: 'Rocha+ ADM Teste', debugShowCheckedModeBanner: false,
      theme: RochaTheme.dark,
      home: controller.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : controller.account?.isAdmin == true
              ? AdminTrialTestScreen(onSignOut: controller.signOut)
              : _AdminLogin(controller: controller),
    ),
  );
}
class _AdminLogin extends StatefulWidget {
  final AuthController controller;
  const _AdminLogin({required this.controller});
  @override
  State<_AdminLogin> createState() => _AdminLoginState();
}
class _AdminLoginState extends State<_AdminLogin> {
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rocha+ ADM')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('Acesso reservado para testar os 7 dias gratuitos.'),
          const SizedBox(height: 20),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail ADM')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Senha ADM')),
          const SizedBox(height: 16),
          FilledButton(onPressed: widget.controller.busy || !widget.controller.ready
            ? null : () => widget.controller.signInAdmin(email.text, password.text),
            child: const Text('Entrar')),
          if (widget.controller.busy) const CircularProgressIndicator(),
          if (widget.controller.error != null)
            Text(widget.controller.error!, style:
              const TextStyle(color: Colors.redAccent)),
        ],
      ))),
    ),
  );
}
