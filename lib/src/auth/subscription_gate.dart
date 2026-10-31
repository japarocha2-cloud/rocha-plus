import 'dart:async';

import 'package:flutter/material.dart';

import 'subscription_access.dart';
import 'playback_permission.dart';
import '../screens/subscription_screen.dart';
import '../cast/revoke_cast_playback.dart';

typedef AccessVerifier = Future<bool> Function(String uid);

/// Owns every protected route, so revocation disposes active local players too.
/// Cast stop is requested too; an offline receiver cannot be proven stopped here.
class SubscriptionGate extends StatefulWidget {
  final String uid;
  final Future<void> Function() onSignOut;
  final WidgetBuilder homeBuilder;
  final AccessVerifier verifyAccess;
  final Duration recheckInterval;
  final Duration verificationTimeout;
  final Future<void> Function()? stopRemotePlayback;
  final PlaybackPermission? playbackPermission;
  final bool showSubscriptionActions;
  final String? blockedMessage;

  const SubscriptionGate({
    super.key,
    required this.uid,
    required this.onSignOut,
    required this.homeBuilder,
    this.verifyAccess = SubscriptionAccess.isAllowed,
    this.recheckInterval = const Duration(minutes: 1),
    this.verificationTimeout = const Duration(seconds: 12),
    this.stopRemotePlayback,
    this.playbackPermission,
    this.showSubscriptionActions = true,
    this.blockedMessage,
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
  bool _remoteCleanupFailed = false;
  late final PlaybackPermission _permission;
  late final Object _playbackOwner;
  Future<bool> _remoteCleanup = Future<bool>.value(true);
  int _cleanupRevision = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.recheckInterval > Duration.zero);
    assert(widget.verificationTimeout > Duration.zero);
    WidgetsBinding.instance.addObserver(this);
    _permission = widget.playbackPermission ?? PlaybackPermission.instance;
    _playbackOwner = _permission.protect();
    _remoteCleanup = _stopRemote();
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
        _permission.revoke(_playbackOwner);
        _allowed = false;
        _resetProtectedRoutes();
        _remoteCleanup = _stopRemote();
      }
    });
    bool allowed;
    try {
      allowed = await widget.verifyAccess(uid).timeout(widget.verificationTimeout);
    } catch (_) {
      allowed = false;
    }
    if (allowed) {
      if (_remoteCleanupFailed) _remoteCleanup = _stopRemote();
      allowed = await _remoteCleanup;
    }
    if (!mounted || generation != _generation || uid != widget.uid) return;
    setState(() {
      _checking = false;
      if (!allowed) {
        _permission.revoke(_playbackOwner);
        if (_allowed) _remoteCleanup = _stopRemote();
        _resetProtectedRoutes();
      }
      _allowed = allowed && _permission.grant(_playbackOwner);
    });
  }

  Future<bool> _stopRemote() async {
    final previous = _remoteCleanup;
    final revision = ++_cleanupRevision;
    await previous;
    try {
      await (widget.stopRemotePlayback ?? revokeCastPlayback)()
          .timeout(const Duration(seconds: 12));
      if (mounted && revision == _cleanupRevision) {
        setState(() => _remoteCleanupFailed = false);
      }
      return true;
    } catch (_) {
      if (mounted && revision == _cleanupRevision) {
        setState(() => _remoteCleanupFailed = true);
      }
      return false;
    }
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
    if (_permission.revoke(_playbackOwner)) unawaited(_stopRemote());
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
                : (widget.blockedMessage ?? 'Acesso não liberado. Confira sua assinatura ou aguarde a confirmação do pagamento.'),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_remoteCleanupFailed)
              const Text('Não foi possível confirmar a parada da TV. '
                  'Desconecte a transmissão na televisão e tente novamente.'),
            OutlinedButton(
              onPressed: _checking ? null : _refresh,
              child: const Text('Verificar novamente'),
            ),
            if (widget.showSubscriptionActions) TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SubscriptionScreen(accountUid: widget.uid),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Minha assinatura'),
            ),
            if (widget.showSubscriptionActions)
              TextButton(onPressed: widget.onSignOut, child: const Text('Sair da conta')),
          ]),
        ),
      ),
    );
  }
}
