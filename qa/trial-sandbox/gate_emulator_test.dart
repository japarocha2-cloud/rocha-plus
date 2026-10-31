import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app_release_policy.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/auth/subscription_gate.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';

void main() {
  testWidgets('explicit sandbox gate consumes real emulator endpoint decisions', (tester) async {
    expect(const bool.fromEnvironment('ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'), isTrue);
    expect(RochaReleasePolicy.stage, RochaReleaseStage.beta);
    expect(RochaReleasePolicy.paidSubscriptionRequired, isTrue);
    final data = jsonDecode(File('qa/trial-sandbox/evidence.json').readAsStringSync()) as Map<String, dynamic>;
    expect(data['project'], 'demo-rocha-sandbox');
    expect(data['trialDurationMs'], 604800000);
    expect(data['trialDocuments'], 1);
    expect(data['providerNetworkCalls'], 0);
    final rows = (data['snapshots'] as List).cast<Map<String, dynamic>>();
    expect(rows.map((row) => row['name']).toList(), [
      'initial', 'one-ms-before', 'exact-expiry', 'after-expiry',
      'fictional-renewal', 'independent-annual',
      'monthly-refund-preserves-annual', 'last-refund-blocks',
    ]);
    var index = 0;
    final permission = PlaybackPermission();
    Future<bool> verify(String uid) async {
      final result = SubscriptionAccessResult.fromPayload(rows[index]['response'], uid);
      expect(result, isNotNull);
      return result!.allowed;
    }
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(
      uid: 'sandbox-trial-gate',
      verifyAccess: verify,
      playbackPermission: permission,
      stopRemotePlayback: () async {},
      onSignOut: () async {},
      homeBuilder: (_) => const Scaffold(body: Text('SANDBOX PROTECTED')),
    )));
    for (var step = 0; step < rows.length; step++) {
      index = step;
      if (step > 0) await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final allowed = (rows[step]['response'] as Map)['allowed'] as bool;
      expect(find.text('SANDBOX PROTECTED'), allowed ? findsOneWidget : findsNothing,
        reason: rows[step]['name'] as String);
      if (allowed) {
        permission.acquire().ensureValid();
      } else {
        expect(permission.acquire, throwsStateError);
        expect(find.textContaining('Acesso não liberado'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
