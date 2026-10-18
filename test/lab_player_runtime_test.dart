import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';

class LabVideoPlatform extends VideoPlayerPlatform {
  bool initializeVideos = true;
  Completer<void>? disposalGate;
  final sources = <String?>[];
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final playing = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource.uri);
    events[id] = StreamController<VideoEvent>.broadcast(sync: true);
    return id;
  }
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (initializeVideos) {
      scheduleMicrotask(() => events[playerId]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(hours: 1), size: const Size(1280, 720))));
    }
    return events[playerId]!.stream;
  }
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await disposalGate?.future;
    await events[playerId]!.close();
  }
  @override
  Future<void> play(int playerId) async { playing.add(playerId); }
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<Duration> getPosition(int playerId) async => const Duration(seconds: 2);
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late LabVideoPlatform platform;
  setUp(() { platform = LabVideoPlatform(); VideoPlayerPlatform.instance = platform; });
  tearDown(() async {
    if (platform.disposalGate?.isCompleted == false) platform.disposalGate!.complete();
    // Controllers are intentionally allowed to finish native disposal later.
    // Do not await stream completion outside the widget test's async clock.
    for (final stream in platform.events.values) { unawaited(stream.close()); }
  });
  const channel = Channel(name: 'Teste local', url: 'https://example.com/test.m3u8');
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PlayerScreen(channel: channel)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('player starts selected URL, handles decoder error and manual reconnection', (tester) async {
    platform.disposalGate = Completer<void>();
    await open(tester);
    expect(platform.sources, [channel.url]);
    expect(platform.playing, [0]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    platform.events[0]!.addError(PlatformException(code: 'VideoError', message: 'Test disconnect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    for (var i = 0; i < 20 && platform.sources.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(platform.sources, [channel.url, channel.url]);
    expect(platform.playing, [0, 1]);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
    await tester.runAsync(() async {
      platform.disposalGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lab permits slow initialization for 25 seconds, then offers retry', (tester) async {
    platform.initializeVideos = false;
    await open(tester);
    await tester.pump(const Duration(seconds: 24));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    for (var i = 0; i < 20 && find.text('Tentar novamente').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  }, skip: !const bool.fromEnvironment('ROCHA_LAB_TEST'));

  testWidgets('leaving during initialization cancels UI updates without an exception', (tester) async {
    platform.initializeVideos = false;
    await open(tester);
    await close(tester);
    await tester.pump(const Duration(seconds: 26));
    expect(find.byType(PlayerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
