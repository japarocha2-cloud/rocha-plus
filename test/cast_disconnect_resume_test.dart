import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/cast_control_screen.dart';

void main() {
  const channel = Channel(name: 'Canal de teste', url: 'https://fixture.example/live.m3u8');
  Future<void> open(WidgetTester tester, Stream<bool> connections,
      Future<void> Function() resume, {bool initiallyConnected = true}) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: TextButton(onPressed: () => Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => CastControlScreen(
          channel: channel, deviceName: 'TV', confirmedContentId: channel.url,
          connectionStream: connections, initiallyConnected: initiallyConnected,
          statusStream: const Stream.empty(), onSessionEnded: resume))),
        child: const Text('Abrir controles'))))));
    await tester.tap(find.text('Abrir controles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lost TV session resumes local playback once and closes TV controls', (tester) async {
    final connections = StreamController<bool>.broadcast();
    var resumed = 0;
    await open(tester, connections.stream, () async { resumed++; });
    expect(find.byType(CastControlScreen), findsOneWidget);
    connections.add(true);
    await tester.pump();
    expect(resumed, 0);
    connections.add(false);
    connections.add(false);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(resumed, 1);
    expect(find.byType(CastControlScreen), findsNothing);
    await connections.close();
  });

  testWidgets('loss before controls open also resumes instead of leaving a paused channel', (tester) async {
    var resumed = 0;
    await open(tester, const Stream.empty(), () async { resumed++; }, initiallyConnected: false);
    await tester.pumpAndSettle();
    expect(resumed, 1);
    expect(find.byType(CastControlScreen), findsNothing);
  });

  testWidgets('account gate removal cancels recovery and cannot reopen private player', (tester) async {
    final connections = StreamController<bool>.broadcast();
    var resumed = 0;
    await open(tester, connections.stream, () async { resumed++; });
    await tester.pumpWidget(const MaterialApp(key: ValueKey('signed-out'), home: Text('Acesso encerrado')));
    connections.add(false);
    await tester.pumpAndSettle();
    expect(resumed, 0);
    expect(find.text('Acesso encerrado'), findsOneWidget);
    await connections.close();
  });
}

