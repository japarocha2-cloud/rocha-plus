import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Read-only trial inspection. All simulation stays local.
class AdminTrialTestScreen extends StatefulWidget {
  final Future<void> Function() onSignOut;
  const AdminTrialTestScreen({super.key, required this.onSignOut});
  @override
  State<AdminTrialTestScreen> createState() => _AdminTrialTestScreenState();
}
class _AdminTrialTestScreenState extends State<AdminTrialTestScreen> {
  final accountId = TextEditingController();
  String message = 'Informe o ID numérico Google da conta de teste.';
  bool busy = false;
  @override
  void dispose() {
    accountId.dispose();
    super.dispose();
  }
  Future<void> consult() async {
    final id = accountId.text.trim();
    if (!RegExp(r'^[0-9]{1,128}$').hasMatch(id)) {
      setState(() => message = 'Informe o identificador numérico da conta Google.');
      return;
    }
    setState(() { busy = true; message = 'Consultando prazo no Firestore…'; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified ||
          (await user.getIdTokenResult(true)).claims?['rochaAdmin'] != true) {
        throw const FormatException('Acesso administrativo não autorizado.');
      }
      final token = await user.getIdToken();
      final project = Firebase.app().options.projectId;
      final uri = Uri.https('firestore.googleapis.com',
        '/v1/projects/$project/databases/(default)/documents/rochaSparkAccounts/$id');
      final response = await http.get(uri,
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) {
        throw const FormatException('Conta não encontrada. Confirme o ID Google.');
      }
      if (response.statusCode != 200) {
        throw FormatException('Consulta não autorizada ou indisponível (' +
          response.statusCode.toString() + ').');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = decoded['fields'] as Map<String, dynamic>?;
      final trial = fields?['trialStartedAt'] as Map<String, dynamic>?;
      final stamp = DateTime.tryParse(trial?['timestampValue'] as String? ?? '');
      if (stamp == null) throw const FormatException('Data de início ausente ou inválida.');
      final now = DateTime.now().toUtc();
      final endsAt = stamp.toUtc().add(const Duration(days: 7));
      final expired = !now.isBefore(endsAt);
      if (!mounted) return;
      setState(() => message =
        'Início: ' + stamp.toLocal().toString() + '\n' +
        'Fim previsto: ' + endsAt.toLocal().toString() + '\n' +
        'Situação estimada: ' + (expired ? 'VENCIDO' : 'EM TESTE') + '\n' +
        'Simulação local após 8 dias: VENCIDO\n' +
        'Essa consulta não substitui o teste real no APK do cliente.');
    } catch (e) {
      if (mounted) setState(() => message = e is FormatException
          ? e.message : 'Não foi possível consultar a conta.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rocha+ ADM | 7 dias'),
      actions: [IconButton(onPressed: () => widget.onSignOut(),
        icon: const Icon(Icons.logout), tooltip: 'Sair')]),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Diagnóstico de teste grátis',
              style: TextStyle(fontSize: 23)),
            const SizedBox(height: 10),
            const Text('Consulta somente leitura. Nenhuma assinatura será alterada.'),
            const SizedBox(height: 20),
            TextField(controller: accountId, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID Google numérico')),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : consult,
              child: const Text('Consultar os 7 dias')),
            const SizedBox(height: 20),
            SelectableText(message),
            const SizedBox(height: 20),
            const Text('A simulação de oito dias é apenas informativa. '
              'O bloqueio real precisa ser testado no APK do assinante.'),
          ],
        ),
      ))),
    )),
  );
}
