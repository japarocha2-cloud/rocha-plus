import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
  static const _diagnostic = bool.fromEnvironment('ROCHA_LAB_DIAGNOSTIC');
  static const _testUid = '6f5WMpl6ZbSprXE5R66SvWtFx2g1';
  bool _creating = false;
  String? _checkoutResult;

  Future<void> _createCheckout() async {
    final auth = FirebaseAuth.instance;
    if (_creating || widget.uid != _testUid ||
        auth.currentUser?.uid != _testUid) return;
    setState(() {
      _creating = true;
      _checkoutResult = null;
    });
    try {
      final token = await auth.currentUser?.getIdToken();
      if (!mounted || token == null || auth.currentUser?.uid != _testUid) return;
      final client = http.Client();
      try {
        final request = http.Request('POST', Uri.parse(
            'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/sandboxCheckout'))
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({'plan': 'monthly'});
        final response = await (() async =>
            http.Response.fromStream(await client.send(request)))()
            .timeout(const Duration(seconds: 35));
        if (!mounted || auth.currentUser?.uid != _testUid) return;
        if (response.statusCode != 200) {
          setState(() => _checkoutResult = 'Checkout retornou HTTP ${response.statusCode}.');
          return;
        }
        final data = jsonDecode(response.body);
        if (data is! Map || data['sandbox'] != true ||
            data['orderId'] is! String ||
            !RegExp(r'^[0-9a-f-]{36} = true;
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
                if (_diagnostic && widget.uid == _testUid) ...[
                  OutlinedButton(
                    onPressed: _checking || _creating ? null : _createCheckout,
                    child: Text(_creating
                        ? 'Gerando pedido…'
                        : 'Gerar checkout de teste'),
                  ),
                  if (_checkoutResult != null) SelectableText(_checkoutResult!),
                ],
                TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sair da conta')),
              ]))),
    );
  }
}
).hasMatch(data['orderId'] as String)) {
          throw const FormatException('Resposta sandbox inválida');
        }
        setState(() => _checkoutResult = 'Pedido sandbox: ${data['orderId']}');
      } finally {
        client.close();
      }
    } catch (_) {
      if (mounted) setState(() => _checkoutResult = 'Não foi possível confirmar a criação do pedido.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

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
