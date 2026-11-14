import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_repository.dart';
import '../auth/firebase_auth_repository.dart';
import '../auth/subscription_access.dart';
import 'subscription_screen.dart';

/// Optional account sign-in for C7 consultation; never gates the LAB catalog.
/// No checkout, trial initialization or client-side grants are implemented here.
class LabSubscriptionScreen extends StatefulWidget {
  final AuthController? authController;
  final Future<SubscriptionAccessResult?> Function(String)? verifyAccess;
  const LabSubscriptionScreen({super.key, this.authController, this.verifyAccess});
  @override
  State<LabSubscriptionScreen> createState() => _LabSubscriptionScreenState();
}

class _LabSubscriptionScreenState extends State<LabSubscriptionScreen> {
  static const queryConfigured = bool.fromEnvironment('ROCHA_C7_SUBSCRIPTION_QUERY');
  late final controller = widget.authController ?? AuthController(FirebaseAuthRepository());
  bool get configured => widget.authController != null ||
      (queryConfigured && FirebaseAuthRepository.isConfigured && SubscriptionAccess.endpoint.isNotEmpty);
  @override
  void initState() {
    super.initState();
    if (configured && controller.initializing) unawaited(controller.initialize());
  }
  @override
  void dispose() {
    if (widget.authController == null) controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => SubscriptionScreen(
      key: ValueKey(controller.account?.uid ?? 'signed-out'),
      accountUid: configured ? controller.account?.uid : null,
      verifyAccess: widget.verifyAccess,
      accountActions: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Consulta LAB • nenhuma cobrança é iniciada nesta tela.'),
        if (!configured)
          const Text('Configuração de autenticação e consulta LAB ausente. Os planos continuam disponíveis para leitura.')
        else if (controller.initializing || controller.busy)
          const LinearProgressIndicator()
        else if (controller.account == null)
          OutlinedButton.icon(
            onPressed: controller.supports(LoginProvider.google)
                ? () => unawaited(controller.signIn(LoginProvider.google)) : null,
            icon: const Icon(Icons.login), label: const Text('Entrar para consultar assinatura'))
        else ...[
          const Text('Conta autenticada. A situação será informada pelo servidor.'),
          TextButton(onPressed: () => unawaited(controller.signOut()), child: const Text('Trocar conta')),
        ],
        if (controller.error != null) Text(controller.error!),
        const SizedBox(height: 16),
      ]),
    ),
  );
}
