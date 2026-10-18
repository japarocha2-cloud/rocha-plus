import 'package:flutter/material.dart';

/// The server-issued rochaAdmin claim is checked during authentication.
/// This screen deliberately provides no direct database management actions.
class AdminHomeScreen extends StatelessWidget {
  final Future<void> Function() onSignOut;
  const AdminHomeScreen({super.key, required this.onSignOut});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rocha+ | Administração'),
      actions: [IconButton(icon: const Icon(Icons.logout),
        tooltip: 'Sair', onPressed: () async => onSignOut())]),
    body: const Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Acesso administrativo autenticado. '
        'Ferramentas de gestão ainda não foram habilitadas.',
        textAlign: TextAlign.center),
    )),
  );
}
