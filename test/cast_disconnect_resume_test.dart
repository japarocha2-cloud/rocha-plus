import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/cast_control_screen.dart';

void main() {
  const channel = Channel(name: 'Canal de teste', url: 'https://fixture.example/live.m3u8');
  Future<void> open(WidgetTester tester, Stream<bool> connections,
      Future<void> Function() resume, {bool initiallyConnected = true,
      Stream<GoggleCastMediaStatus?> statuses = const Stream.empty(),
      Future<bool> Function()? recover}) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: TextButton(onPressed: () => Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => CastControlScreen(
          channel: channel, deviceName: 'TV', confirmedContentId: channel.url,
          connectionStream: connections, initiallyConnected: initiallyConnected,
          statusStream: statuses, onSessionEnded: resume, onMediaFailure: recover))),
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
  testWidgets('receiver media ERROR resumes locally even while Cast session is connected', (tester) async {
    final statuses = StreamController<GoggleCastMediaStatus?>.broadcast();
    var resumed = 0;
    await open(tester, const Stream.empty(), () async { resumed++; }, statuses: statuses.stream);
    GoggleCastMediaStatus status(String id, CastMediaPlayerState state, GoogleCastMediaIdleReason? reason) =>
      GoggleCastMediaStatus(mediaSessionID: 7, playerState: state, idleReason: reason,
        playbackRate: 1, volume: 1, isMuted: false, repeatMode: GoogleCastMediaRepeatMode.off,
        mediaInformation: GoogleCastMediaInformation(contentId: id,
          contentUrl: Uri.parse(id), contentType: 'application/x-mpegURL', streamType: CastMediaStreamType.live));
    // Unrelated/stale errors and an intentional pause must not end this playback.
    statuses.add(status('https://other.example/live.m3u8', CastMediaPlayerState.idle, GoogleCastMediaIdleReason.error));
    await tester.pump();
    statuses.add(status(channel.url, CastMediaPlayerState.paused, null));
    await tester.pump();
    expect(resumed, 0);
    statuses.add(status(channel.url, CastMediaPlayerState.idle, GoogleCastMediaIdleReason.error));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(resumed, 1);
    expect(find.byType(CastControlScreen), findsNothing);
    await statuses.close();
  });

  testWidgets('media recovery keeps TV controls open and does not resume phone while retrying', (tester) async {
    final statuses = StreamController<GoggleCastMediaStatus?>.broadcast();
    final recovery = Completer<bool>();
    var localResumes = 0;
    var remoteRetries = 0;
    await open(tester, const Stream.empty(), () async { localResumes++; },
      statuses: statuses.stream, recover: () { remoteRetries++; return recovery.future; });
    statuses.add(GoggleCastMediaStatus(mediaSessionID: 7, playerState: CastMediaPlayerState.idle,
      idleReason: GoogleCastMediaIdleReason.error, playbackRate: 0, volume: 1, isMuted: false,
      repeatMode: GoogleCastMediaRepeatMode.off,
      mediaInformation: GoogleCastMediaInformation(contentId: channel.url,
        contentUrl: Uri.parse(channel.url), contentType: 'application/x-mpegURL', streamType: CastMediaStreamType.live)));
    await tester.pump();
    await tester.pump();
    expect(remoteRetries, 1);
    expect(localResumes, 0);
    expect(find.text('Reconectando na TV…'), findsOneWidget);
    recovery.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CastControlScreen), findsOneWidget);
    expect(localResumes, 0);
    expect(remoteRetries, 1);
    await tester.pumpWidget(const SizedBox());
    await statuses.close();
  });

}
