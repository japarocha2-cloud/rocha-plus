import 'dart:async';
import 'package:flutter/material.dart';
import 'lab_entitlement.dart';

typedef LabVerifier = Future<LabAccess> Function(String uid);

class LabAccessGate extends StatefulWidget {
  final String uid;
  final LabVerifier verify;
  final WidgetBuilder homeBuilder;
  final VoidCallback onSignOut;
  const LabAccessGate(
      {super.key,
      required this.uid,
      required this.verify,
      required this.homeBuilder,
      required this.onSignOut});
  @override
  State<LabAccessGate> createState() => _LabAccessGateState();
}

class _LabAccessGateState extends State<LabAccessGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _allowed = false;
  int _generation = 0;
  Timer? _expiry;
  var _navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    _expiry?.cancel();
    setState(() {
      _checking = true;
      _allowed = false;
      _navigator = GlobalKey<NavigatorState>();
    });
    LabAccess result;
    try {
      result =
          await widget.verify(widget.uid).timeout(const Duration(seconds: 12));
    } catch (_) {
      result = LabAccess.denied;
    }
    if (!mounted || generation != _generation) return;
    final allowed = result.allowed &&
        result.lifetime > Duration.zero &&
        result.lifetime <= const Duration(minutes: 1);
    setState(() {
      _checking = false;
      _allowed = allowed;
    });
    if (allowed) _expiry = Timer(result.lifetime, () => unawaited(_refresh()));
  }

  @override
  void didUpdateWidget(covariant LabAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    _generation++;
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) {
      return NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => unawaited(_navigator.currentState!.maybePop()),
        child: Navigator(
            key: _navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: widget.homeBuilder)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Rocha+ LAB • Acesso')),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_checking) const CircularProgressIndicator(),
                Text(_checking
                    ? 'Consultando sua autorização…'
                    : 'Não foi possível confirmar acesso autorizado. Nenhum acesso foi concedido.'),
                OutlinedButton(
                    onPressed: _checking ? null : _refresh,
                    child: const Text('Verificar novamente')),
                TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sair da conta')),
              ]))),
    );
  }
}
