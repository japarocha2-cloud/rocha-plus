import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'roku_pairing_service.dart';

class RokuPairingScreen extends StatefulWidget {
  final RokuPairingService service;
  const RokuPairingScreen({super.key, required this.service});
  @override
  State<RokuPairingScreen> createState() => _RokuPairingScreenState();
}
class _RokuPairingScreenState extends State<RokuPairingScreen> {
  final code = TextEditingController();
  bool busy = false;
  bool approved = false;
  String? error;
  @override
  void dispose() { code.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy) return;
    setState(() {busy = true; error = null;});
    try {
      await widget.service.approve(code.text);
      if (mounted) setState(() => approved = true);
    } on RokuPairingFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conectar Roku')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(approved ? Icons.check_circle_outline : Icons.tv, size: 64),
          const SizedBox(height: 24),
          Text(approved ? 'TV confirmada na sua conta' : 'Digite o código que aparece na sua Roku',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          if (!approved) ...[
            TextField(controller: code, enabled: !busy, autofocus: true,
              maxLength: 8, textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z2-9]'))],
              decoration: InputDecoration(labelText: 'Código da TV', errorText: error),
              onSubmitted: (_) => submit()),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : submit,
              child: Text(busy ? 'Confirmando…' : 'Confirmar esta TV')),
          ] else ...[
            const Text('Sua Roku concluirá a conexão em alguns segundos.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Concluir')),
          ],
        ]))),
  );
}
