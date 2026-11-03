import 'dart:async';
import 'package:flutter/material.dart';
import 'central_rights_runtime.dart';

class CentralTvLinkScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onLinked;
  const CentralTvLinkScreen({super.key, required this.uid, required this.onLinked});
  @override
  State<CentralTvLinkScreen> createState() => _CentralTvLinkScreenState();
}
class _CentralTvLinkScreenState extends State<CentralTvLinkScreen> {
  Timer? _poll, _expiry;
  String _message = 'Confirmando vinculação da TV...', _code = '';
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() { super.initState(); _start(); }
  Future<void> _start() async {
    final generation = ++_generation;
    _poll?.cancel(); _expiry?.cancel();
    try {
      if (await CentralRightsRuntime.restoreTv(widget.uid)) {
        if (mounted && generation == _generation) widget.onLinked();
        return;
      }
      final client = await CentralRightsRuntime.client(widget.uid);
      final code = await client.startTvPairing();
      if (!mounted || generation != _generation) return;
      setState(() { _code = code; _message = 'No fluxo autenticado do celular, confirme este código. Válido por até 10 minutos.'; });
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check(generation));
      _expiry = Timer(const Duration(minutes: 10), () {
        _poll?.cancel();
        if (mounted) setState(() { _code = ''; _message = 'Código expirado. Gere outro código.'; });
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _message = 'Vinculação indisponível. Nenhum acesso foi concedido.');
    }
  }
  Future<void> _check(int generation) async {
    if (_busy) return;
    _busy = true;
    try {
      final client = await CentralRightsRuntime.client(widget.uid);
      final lease = await client.pollTvPairing();
      if (lease != null && mounted && generation == _generation) {
        await CentralRightsRuntime.saveTv(widget.uid);
        if (!mounted || generation != _generation) return;
        _poll?.cancel(); _expiry?.cancel(); widget.onLinked();
      }
    } catch (_) { /* pending/network never grants access */ }
    finally { _busy = false; }
  }
  @override
  void dispose() { _generation++; _poll?.cancel(); _expiry?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      const Text('Vincular esta TV ao Rocha+'),
      Text(_code, style: Theme.of(context).textTheme.headlineLarge),
      Text(_message, textAlign: TextAlign.center),
      TextButton(autofocus: true, onPressed: _start, child: const Text('Gerar outro código')),
    ],
  )));
}
