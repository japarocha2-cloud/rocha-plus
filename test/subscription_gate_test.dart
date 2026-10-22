import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import 'package:rocha_plus/src/auth/subscription_gate.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';

// Real PlayerScreen/VideoPlayerController lifecycle with a fake platform only.
// This proves disposal requests; it does not prove physical decoder/Cast stop.
class RecordingVideoPlatform extends VideoPlayerPlatform {
  int nextId = 0;
  final streams = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};
  final disposed = <int>[];
  final events = <String>[];

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    final id = nextId++;
    events.add('create:$id');
    // A synchronous/null onCancel makes StreamSubscription.cancel return the
    // SDK's root-zone Future._nullFuture, which FakeAsync pumps cannot drain.
    // Model the native asynchronous cancellation explicitly in this test zone.
    final stream = StreamController<VideoEvent>(onCancel: () async {
      events.add('events-cancel:$id');
      await Future<void>.value();
      events.add('events-cancel-completed:$id');
    });
    // Allocate done in the test zone too; close after cancel must not fall back
    // to the same root-zone singleton while completing the fake native dispose.
    unawaited(stream.done);
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
    events.add('native-dispose:$playerId');
    disposed.add(playerId);
    playing.remove(playerId);
    await streams.remove(playerId)?.close();
    events.add('native-dispose-completed:$playerId');
  }
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> play(int playerId) async {
    events.add('play:$playerId');
    playing.add(playerId);
  }
  @override
  Future<void> pause(int playerId) async {
    events.add('pause:$playerId');
    playing.remove(playerId);
  }
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

Future<void> noRemotePlayback() async {}

Widget gateApp(AccessVerifier verify, {String uid = 'one', bool fullscreen = false,
    PlaybackPermission? permission, Future<void> Function()? stopRemote}) =>
    MaterialApp(home: SubscriptionGate(
      uid: uid,
      verifyAccess: verify,
      playbackPermission: permission,
      stopRemotePlayback: stopRemote ?? noRemotePlayback,
      onSignOut: () async {},
      homeBuilder: (context) => Scaffold(body: TextButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
              PlaybackLifecycleProbe(
                events: (VideoPlayerPlatform.instance as RecordingVideoPlatform).events,
                child: PlayerScreen(channel: fixtureChannel, initiallyFullscreen: fullscreen),
              )));
        },
        child: Text('Abrir player $uid'),
      )),
    ));

class PlaybackLifecycleProbe extends StatefulWidget {
  final List<String> events;
  final Widget child;
  const PlaybackLifecycleProbe({super.key, required this.events, required this.child});
  @override
  State<PlaybackLifecycleProbe> createState() => _PlaybackLifecycleProbeState();
}

class _PlaybackLifecycleProbeState extends State<PlaybackLifecycleProbe> {
  @override
  void deactivate() {
    widget.events.add('route-deactivate');
    super.deactivate();
  }
  @override
  void dispose() {
    widget.events.add('route-dispose');
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> pumpUntil(WidgetTester tester, bool Function() condition,
    RecordingVideoPlatform video, String phase) async {
  // Navigator/Overlay removal and VideoPlayerController disposal are async.
  // Keep a strict two-second bound and all native disposal assertions.
  for (var frame = 0; frame < 40 && !condition(); frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: '$phase did not complete within 2 seconds; '
      'players including offstage=${find.byType(PlayerScreen, skipOffstage: false).evaluate().length}; '
      'playing=${video.playing}; disposed=${video.disposed}; events=${video.events}');
}

Future<void> expectPlaybackStopped(WidgetTester tester, RecordingVideoPlatform video) async {
  await pumpUntil(tester, () =>
      find.byType(PlayerScreen, skipOffstage: false).evaluate().isEmpty &&
      video.disposed.contains(0) && video.playing.isEmpty &&
      video.events.contains('native-dispose-completed:0'),
      video, 'protected route destruction and platform disposal');
  expect(video.events, contains('route-dispose'));
  expect(video.events, contains('events-cancel:0'));
  expect(video.events, contains('events-cancel-completed:0'));
  expect(video.events, contains('native-dispose-completed:0'));
}

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> openPlayer(WidgetTester tester, RecordingVideoPlatform video) async {
  await tester.tap(find.text('Abrir player one'));
  await flush(tester);
  await pumpUntil(tester, () {
    final players = find.byType(PlayerScreen);
    if (players.evaluate().length != 1 || video.playing.length != 1) return false;
    return ModalRoute.of(tester.element(players))?.animation?.isCompleted == true;
  }, video, 'player route entrance');
  // Let NavigationNotification reach the parent PopScope before system Back.
  await tester.pump();
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

  testWidgets('platform lifecycle baseline disposes without any Navigator', (tester) async {
    // Report only the resolved package's lock entry, never environment values.
    final lock = File('pubspec.lock');
    if (lock.existsSync()) {
      final entry = RegExp(r'  video_player:\n[\s\S]*?(?=\n  \w|\nsdks:|$)')
          .firstMatch(lock.readAsStringSync())?.group(0);
      debugPrint('Resolved video_player lifecycle baseline: $entry');
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(fixtureChannel.url));
    await controller.initialize();
    await controller.play();
    expect(video.playing, contains(0));
    var disposeCompleted = false;
    unawaited(controller.dispose().then((_) { disposeCompleted = true; }));
    await pumpUntil(tester, () => disposeCompleted && video.playing.isEmpty &&
        video.events.contains('events-cancel-completed:0') &&
        video.events.contains('native-dispose-completed:0'), video, 'direct controller baseline');
    expect(video.disposed, contains(0));
    expect(video.events, containsAllInOrder(['events-cancel:0',
        'events-cancel-completed:0', 'native-dispose:0', 'native-dispose-completed:0']));
  });

  testWidgets('initial denial never creates protected content', (tester) async {
    Future<bool> verify(String _) async => false;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    expect(find.text('Abrir player one'), findsNothing);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(video.nextId, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expiration removes fullscreen route and disposes its actual controller', (tester) async {
    var allowed = true;
    Future<bool> verify(String _) async => allowed;
    await tester.pumpWidget(gateApp(verify, fullscreen: true));
    await flush(tester);
    await openPlayer(tester, video);
    allowed = false;
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    await expectPlaybackStopped(tester, video);
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
    Future<bool> verify(String _) async {
      if (networkFails) throw StateError('network unavailable');
      return true;
    }
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    networkFails = true;
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    await expectPlaybackStopped(tester, video);
    expect(video.disposed, contains(0));
    expect(video.playing, isEmpty);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('verification timeout revokes player and ignores a late positive result', (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    Future<bool> verify(String _) => ++calls == 1 ? Future.value(true) : pending.future;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 13));
    await flush(tester);
    await expectPlaybackStopped(tester, video);
    expect(video.playing, isEmpty);
    expect(video.disposed, contains(0));
    expect(find.byType(PlayerScreen), findsNothing);
    pending.complete(true);
    await flush(tester);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful periodic recheck keeps the same live controller', (tester) async {
    Future<bool> verify(String _) async => true;
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
    Future<bool> verify(String _) async => true;
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.binding.handlePopRoute();
    await flush(tester);
    await expectPlaybackStopped(tester, video);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('Abrir player one'), findsOneWidget);
    expect(video.disposed, contains(0));
    expect(video.playing, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('revocation invalidates pending Cast permits and waits for remote shutdown before regrant', (tester) async {
    final permission = PlaybackPermission();
    final stopped = Completer<void>();
    var calls = 0;
    var allowed = true;
    Future<bool> verify(String _) async => allowed;
    Future<void> stopRemote() async {
      calls++;
      if (calls > 1) await stopped.future;
    }
    await tester.pumpWidget(gateApp(verify,
        permission: permission, stopRemote: stopRemote));
    await flush(tester);
    await openPlayer(tester, video);
    final pendingCast = permission.acquire();
    allowed = false;
    await tester.pump(const Duration(minutes: 1));
    await flush(tester);
    await expectPlaybackStopped(tester, video);
    expect(pendingCast.ensureValid, throwsStateError);
    expect(permission.acquire, throwsStateError);
    expect(calls, 2);
    allowed = true;
    await tester.tap(find.text('Verificar novamente'));
    await flush(tester);
    expect(find.text('Abrir player one'), findsNothing);
    stopped.complete();
    await flush(tester);
    expect(find.text('Abrir player one'), findsOneWidget);
    permission.acquire().ensureValid();
    expect(pendingCast.ensureValid, throwsStateError);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('remote shutdown failure cannot grant access or claim a stopped TV', (tester) async {
    final permission = PlaybackPermission();
    Future<bool> verify(String _) async => true;
    Future<void> stopRemote() async => throw StateError('receiver offline');
    await tester.pumpWidget(gateApp(verify,
        permission: permission, stopRemote: stopRemote));
    await flush(tester);
    expect(find.text('Abrir player one'), findsNothing);
    expect(permission.acquire, throwsStateError);
    expect(find.textContaining('Não foi possível confirmar a parada da TV'), findsOneWidget);
    expect(video.nextId, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('UID change disposes old route and cannot inherit prior or delayed grant', (tester) async {
    final pendingOldUid = Completer<bool>();
    var calls = 0;
    Future<bool> verify(String uid) {
      if (uid == 'two') return Future.value(false);
      return ++calls == 1 ? Future.value(true) : pendingOldUid.future;
    }
    await tester.pumpWidget(gateApp(verify));
    await flush(tester);
    await openPlayer(tester, video);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(gateApp(verify, uid: 'two'));
    await flush(tester);
    pendingOldUid.complete(true);
    await flush(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    await expectPlaybackStopped(tester, video);
    expect(video.playing, isEmpty);
    expect(video.disposed, contains(0));
    expect(find.text('Abrir player two'), findsNothing);
    expect(find.textContaining('Acesso não liberado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
