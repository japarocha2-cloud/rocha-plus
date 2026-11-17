import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rocha_plus/src/auth/playback_permission.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/auth/subscription_gate.dart';
import 'package:rocha_plus/src/auth/trial_welcome_store.dart';
import 'package:rocha_plus/src/screens/trial_welcome_dialog.dart';

Future<void> noRemote() async {}

SubscriptionAccessResult? serverSays(String uid, {required bool allowed, String? reason}) =>
    SubscriptionAccessResult.fromPayload({'uid': uid, 'allowed': allowed, 'reason': reason}, uid);

Widget gate(String uid, AccessChecker check) => MaterialApp(
      home: SubscriptionGate(
        uid: uid,
        checkAccess: check,
        playbackPermission: PlaybackPermission(),
        stopRemotePlayback: noRemote,
        onSignOut: () async {},
        homeBuilder: (_) => const Scaffold(body: Text('HOME CANAIS')),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('server-confirmed trial shows the approved welcome once on Home', (tester) async {
    var calls = 0;
    await tester.pumpWidget(gate('U1', (uid) async {
      calls++;
      return serverSays(uid, allowed: true, reason: 'trial');
    }));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('HOME CANAIS'), findsOneWidget);
    expect(find.byType(TrialWelcomeDialog), findsOneWidget);
    expect(find.text('Você ganhou'), findsOneWidget);
    expect(find.text('7 dias grátis!'), findsOneWidget);
    expect(find.textContaining('R\$ 7,90'), findsOneWidget);
    expect(find.textContaining('R\$ 86,90'), findsOneWidget);
    await tester.ensureVisible(find.byKey(TrialWelcomeDialog.startKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TrialWelcomeDialog.startKey));
    await tester.pumpAndSettle();
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    expect(find.text('HOME CANAIS'), findsOneWidget);
    expect((await SharedPreferences.getInstance())
        .getBool(TrialWelcomeStore.keyFor('U1')), isTrue);

    // New login / app restart for the same account: no second welcome.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(gate('U1', (uid) async => serverSays(uid, allowed: true, reason: 'trial')));
    await tester.pumpAndSettle();
    expect(find.text('HOME CANAIS'), findsOneWidget);
    expect(find.byType(TrialWelcomeDialog), findsNothing);
  });

  testWidgets('close button also dismisses and records the welcome', (tester) async {
    await tester.pumpWidget(gate('U2', (uid) async => serverSays(uid, allowed: true, reason: 'trial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TrialWelcomeDialog.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    expect(await TrialWelcomeStore().wasShown('U2'), isTrue);
  });

  for (final (label, allowed, reason) in [
    ('paid subscription', true, 'paid'),
    ('expired trial', false, 'expired'),
    ('unknown/ineligible reason', true, null),
  ]) {
    testWidgets('$label never shows the new-benefit welcome', (tester) async {
      await tester.pumpWidget(gate('U3', (uid) async => serverSays(uid, allowed: allowed, reason: reason)));
      await tester.pumpAndSettle();
      expect(find.byType(TrialWelcomeDialog), findsNothing);
      expect(await TrialWelcomeStore().wasShown('U3'), isFalse);
    });
  }

  testWidgets('revocation while the welcome is open removes it with Home', (tester) async {
    var allowed = true;
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(
      uid: 'R',
      checkAccess: (uid) async => serverSays(uid, allowed: allowed, reason: allowed ? 'trial' : 'expired'),
      recheckInterval: const Duration(seconds: 5),
      playbackPermission: PlaybackPermission(),
      stopRemotePlayback: noRemote,
      onSignOut: () async {},
      homeBuilder: (_) => const Scaffold(body: Text('HOME CANAIS')),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TrialWelcomeDialog), findsOneWidget);
    allowed = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    expect(find.text('HOME CANAIS'), findsNothing);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
  });

  testWidgets('server failure keeps the gate closed and shows no welcome', (tester) async {
    await tester.pumpWidget(gate('U4', (_) async => null));
    await tester.pumpAndSettle();
    expect(find.text('HOME CANAIS'), findsNothing);
    expect(find.byType(TrialWelcomeDialog), findsNothing);
  });

  testWidgets('another account on the same device still gets its own welcome', (tester) async {
    SharedPreferences.setMockInitialValues({TrialWelcomeStore.keyFor('OLD'): true});
    await tester.pumpWidget(gate('NEW', (uid) async => serverSays(uid, allowed: true, reason: 'trial')));
    await tester.pumpAndSettle();
    expect(find.byType(TrialWelcomeDialog), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(360, 640), const Size(412, 915), const Size(800, 1280)]) {
    testWidgets('welcome fits without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(gate('S', (uid) async => serverSays(uid, allowed: true, reason: 'trial')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(TrialWelcomeDialog.startKey), findsOneWidget);
    });
  }
}
