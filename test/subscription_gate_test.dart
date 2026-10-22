import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:rocha_plus/src/auth/subscription_gate.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';

// Real PlayerScreen/VideoPlayerController lifecycle with a fake platform only.
// This proves disposal requests; it does not prove physical decoder/Cast stop.
class RecordingVideoPlatform extends VideoPlayerPlatform {
  int nextId = 0;
  final streams = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};
  final disposed = <int>[];

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    final id = nextId++;
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    stream.add(VideoEvent(
      eventType: VideoEventType.initialized,
      size: const Size(640, 360),
      duration: const Duration(hours: 1),
    ));
    return id;
  }
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
    await streams.remove(playerId)?.close();
  }
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> play(int playerId) async { playing.add(playerId); }
  @override
  Future<void> pause(int playerId) async { playing.remove(playerId); }
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
}

const fixtureChannel = Channel(name: 'Teste de encerramento local',
    url: 'https://example.invalid/fixture.m3u8');

Widget gateApp(AccessVerifier verify, {String uid = 'one', bool fullscreen = false}) =>
    MaterialApp(home: SubscriptionGate(
      uid: uid,
      verifyAccess: verify,
      onSignOut: () async {},
      homeBuilder: (context) => Scaffold(body: TextButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
              PlayerScreen(channel: fixtureChannel, initiallyFullscreen: fullscreen)));
        },
        child: Text('Abrir player $uid'),
      )),
    ));

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> openPlayer(WidgetTester tester, RecordingVideoPlatform video) async {
  await tester.tap(find.text('Abrir player one'));
  await flush(tester);
  expect(find.byType(PlayerScreen), findsOneWidget);
  expect(video.playing, hasLength(1));
}

void main() {
  late RecordingVideoPlatform video;
  late VideoPlayerPlatform originalPlatform;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalPlatform = VideoPlayerPlatform.instance;
    video = RecordingVideoPlatform();
    VideoPlayerPlatform.instance = video;
  });
  tearDown(() { VideoPlayerPlatform.instance = originalPlatform; });

  testWidgets('initial denial never creates protected content', (tester) async {
    final AccessVerifier verify = (_) async => false;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    expect(find.text('Abrir player one'), findsNothing);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(video.nextId, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expiration removes fullscreen route and disposes its actual controller', (tester) async {
    var allowed = true;
    final AccessVerifier verify = (_) async => allowed;
    await tester.pumpWidget(gateApp(verify, fullscreen: true));
    await flush(tester);
    await openPlayer(tester, video);
    allowed = false;
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(video.disposed, contains(0));
    expect(video.playing, isEmpty);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    // New authorization starts at Home; the expired route must not reappear.
    allowed = true;
    await tester.tap(find.text('Verificar novamente'));
    await flush(tester);
    expect(find.text('Abrir player one'), findsOneWidget);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(video.nextId, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('network error revokes existing playback instead of retaining stale success', (tester) async {
    var networkFails = false;
    final AccessVerifier verify = (_) async {
      if (networkFails) throw StateError('network unavailable');
      return true;
    };
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    networkFails = true;
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(video.disposed, contains(0));
    expect(video.playing, isEmpty);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('verification timeout revokes player and ignores a late positive result', (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    final AccessVerifier verify = (_) => ++calls == 1 ? Future.value(true) : pending.future;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 13));
    await flush(tester);
    expect(video.playing, isEmpty);
    expect(video.disposed, contains(0));
    expect(find.byType(PlayerScreen), findsNothing);
    pending.complete(true);
    await flush(tester);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful periodic recheck keeps the same live controller', (tester) async {
    final AccessVerifier verify = (_) async => true;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(video.nextId, 1);
    expect(video.disposed, isEmpty);
    expect(video.playing, contains(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('system back pops protected player without bypassing its gate', (tester) async {
    final AccessVerifier verify = (_) async => true;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.binding.handlePopRoute();
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('Abrir player one'), findsOneWidget);
    expect(video.disposed, contains(0));
    expect(video.playing, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('UID change disposes old route and cannot inherit prior or delayed grant', (tester) async {
    final pendingOldUid = Completer<bool>();
    var calls = 0;
    final AccessVerifier verify = (uid) {
      if (uid == 'two') return Future.value(false);
      return ++calls == 1 ? Future.value(true) : pendingOldUid.future;
    };
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(gateApp(verify, uid: 'two'));
    await flush(tester);
    pendingOldUid.complete(true);
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(video.playing, isEmpty);
    expect(video.disposed, contains(0));
    expect(find.text('Abrir player two'), findsNothing);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
