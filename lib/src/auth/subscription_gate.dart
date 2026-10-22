import 'dart:async';

import 'package:flutter/material.dart';

import 'subscription_access.dart';

typedef AccessVerifier = Future<bool> Function(String uid);

/// Owns every protected route, so revocation disposes active local players too.
/// This gate does not revoke a stream already loaded on a remote Cast receiver.
class SubscriptionGate extends StatefulWidget {
  final String uid;
  final Future<void> Function() onSignOut;
  final WidgetBuilder homeBuilder;
  final AccessVerifier verifyAccess;
  final Duration recheckInterval;
  final Duration verificationTimeout;

  const SubscriptionGate({
    super.key,
    required this.uid,
    required this.onSignOut,
    required this.homeBuilder,
    this.verifyAccess = SubscriptionAccess.isAllowed,
    this.recheckInterval = const Duration(minutes: 1),
    this.verificationTimeout = const Duration(seconds: 12),
  });

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate>
    with WidgetsBindingObserver {
  var _protectedNavigator = GlobalKey<NavigatorState>();
  var _heroController = HeroController();
  Timer? _timer;
  int _generation = 0;
  bool _allowed = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    assert(widget.recheckInterval > Duration.zero);
    assert(widget.verificationTimeout > Duration.zero);
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.recheckInterval, (_) => _refresh());
  }

  Future<void> _refresh({bool clearAccess = false}) async {
    if (!mounted) return;
    final generation = ++_generation;
    final uid = widget.uid;
    setState(() {
      _checking = true;
      if (clearAccess) {
        _allowed = false;
        _resetProtectedRoutes();
      }
    });
    bool allowed;
    try {
      allowed = await widget.verifyAccess(uid).timeout(widget.verificationTimeout);
    } catch (_) {
      allowed = false;
    }
    if (!mounted || generation != _generation || uid != widget.uid) return;
    setState(() {
      _checking = false;
      if (!allowed) _resetProtectedRoutes();
      _allowed = allowed;
    });
  }

  void _resetProtectedRoutes() {
    _protectedNavigator = GlobalKey<NavigatorState>();
    _heroController = HeroController();
  }

  @override
  void didUpdateWidget(covariant SubscriptionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.verifyAccess != widget.verifyAccess) {
      _refresh(clearAccess: true);
    }
    if (oldWidget.recheckInterval != widget.recheckInterval) _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // No stale grant is shown after returning from a suspended/background app.
      _refresh(clearAccess: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) {
      // Removing this whole subtree bypasses route-specific back restrictions
      // and runs dispose on local Exo/VLC player widgets, even in fullscreen.
      return HeroControllerScope.none(
        child: NavigatorPopHandler<Object?>(
          onPopWithResult: (_) {
            final navigator = _protectedNavigator.currentState;
            if (navigator != null) unawaited(navigator.maybePop());
          },
          child: Navigator(
            key: _protectedNavigator,
            observers: [_heroController],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: widget.homeBuilder,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Rocha+ • Assinatura')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 52),
            const SizedBox(height: 18),
            Text(_checking
                ? 'Verificando sua assinatura...'
                : 'Acesso não liberado. Confira sua assinatura ou aguarde a confirmação do pagamento.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _checking ? null : _refresh,
              child: const Text('Verificar novamente'),
            ),
            TextButton(onPressed: widget.onSignOut, child: const Text('Sair da conta')),
          ]),
        ),
      ),
    );
  }
}
