import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'central_rights_runtime.dart';
import '../cast/revoke_cast_playback.dart';

/// Removes the real player subtree at lease expiry. Idle Home has no stream slot.
class CentralPlaybackBoundary extends StatefulWidget {
  final Widget child;
  const CentralPlaybackBoundary({super.key, required this.child});
  @override
  State<CentralPlaybackBoundary> createState() => _CentralPlaybackBoundaryState();
}
class _CentralPlaybackBoundaryState extends State<CentralPlaybackBoundary>
    with WidgetsBindingObserver {
  Timer? _expiry, _refresh;
  bool _allowed = false;
  bool _foreground = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (!CentralRightsRuntime.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _check();
    _refresh = Timer.periodic(const Duration(seconds: 25), (_) => _check());
  }
  void _deny() {
    if (!mounted) return;
    _expiry?.cancel();
    setState(() => _allowed = false);
    unawaited(CentralRightsRuntime.stop());
    unawaited(revokeCastPlayback().catchError((Object _) {}));
  }
  Future<void> _check() async {
    if (!_foreground) return;
    final generation = ++_generation;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { _deny(); return; }
    final lease = await CentralRightsRuntime.check(uid, playback: true);
    if (!mounted || generation != _generation) return;
    if (uid != FirebaseAuth.instance.currentUser?.uid || lease == null) { _deny(); return; }
    _expiry?.cancel();
    _expiry = Timer(lease.duration, _deny);
    setState(() => _allowed = true);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    _deny();
    if (_foreground) _check();
  }
  @override
  void dispose() {
    _generation++; _expiry?.cancel(); _refresh?.cancel();
    if (CentralRightsRuntime.enabled) {
      WidgetsBinding.instance.removeObserver(this);
      unawaited(CentralRightsRuntime.stop());
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => !CentralRightsRuntime.enabled || _allowed
      ? widget.child
      : Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('A reprodução aguarda autorização do serviço central.'),
          TextButton(onPressed: _check, child: const Text('Verificar novamente')),
        ])));
}
