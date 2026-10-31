import 'package:flutter/material.dart';

import '../auth/playback_permission.dart';
import '../auth/subscription_gate.dart';

/// Demonstrates the existing gate with local fictitious rights only.
///
/// This screen never requests Firebase credentials, talks to an endpoint,
/// processes a payment or changes the device clock. It is not a production
/// subscription verification and is reachable only from a LAB build.
class TrialExpiryLabScreen extends StatefulWidget {
  const TrialExpiryLabScreen({super.key});

  @override
  State<TrialExpiryLabScreen> createState() => _TrialExpiryLabScreenState();
}

class _TrialExpiryLabScreenState extends State<TrialExpiryLabScreen> {
  bool _trialValid = true;
  int _revision = 0;
  final PlaybackPermission _permission = PlaybackPermission();

  Future<bool> _verify(String uid) async =>
      uid == 'lab-fictitious-user' && _trialValid;

  void _setTrial(bool valid) {
    setState(() {
      _trialValid = valid;
      // Force the gate to revoke its prior permit and verify again.
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LAB • vencimento fictício')),
    body: Column(children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('SIMULAÇÃO LOCAL: não representa assinatura real. '
            'Não altera o trial instalado nem o relógio do aparelho.'),
      ),
      Wrap(spacing: 8, children: [
        FilledButton(
          onPressed: () => _setTrial(true),
          child: const Text('Simular trial válido'),
        ),
        FilledButton(
          onPressed: () => _setTrial(false),
          child: const Text('Simular vencimento'),
        ),
      ]),
      Expanded(
        child: SubscriptionGate(
          key: ValueKey(_revision),
          uid: 'lab-fictitious-user',
          verifyAccess: _verify,
          showSubscriptionActions: false,
          playbackPermission: _permission,
          stopRemotePlayback: () async {},
          recheckInterval: const Duration(seconds: 2),
          onSignOut: () async => _setTrial(false),
          homeBuilder: (_) => const Center(
            child: Text('ACESSO FICTÍCIO LIBERADO • LAB'),
          ),
        ),
      ),
    ]),
  );
}
