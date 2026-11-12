import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';

// Native transport only is simulated. The real PlayerScreen/controller runs.
class FixtureVideo extends VideoPlayerPlatform {
  int count = 0;
  final disposed = <int>[];
  final played = <int>[];
  final events = <int, StreamController<VideoEvent>>{};
  bool fail = false;
  bool initializeVideo = true;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++count;
    // Model EventChannel cancellation with an asynchronous completion in the
    // current test zone, so VideoPlayerController.dispose() can finish.
    events[id] = StreamController<VideoEvent>(onCancel: () async {});
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (fail) {
      events[playerId]!
          .addError(PlatformException(code: 'fixture-stream-error', message: 'Fixture stream failed'));
    } else if (initializeVideo) {
      events[playerId]!.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(hours: 1),
          size: const Size(1280, 720)));
    }
    return events[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
  }

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
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

Future<void> advance(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FixtureVideo platform;
  late VideoPlayerPlatform original;
  setUp(() {
    original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform = FixtureVideo();
  });
  tearDown(() async {
    for (final stream in platform.events.values) {
      await stream.close();
    }
    VideoPlayerPlatform.instance = original;
  });
  Widget player(String url) => MaterialApp(
      home: PlayerScreen(
          channel: Channel(name: 'Fixture only â€” no real stream', url: url)));

  testWidgets(
      'stream failure shows recovery and retry prepares a new controller',
      (tester) async {
    platform.fail = true;
    await tester.pumpWidget(player('https://fixture.invalid/error'));
    await advance(tester);
    expect(find.text('Tentar novamente'), findsOneWidget, reason: 'native created=${platform.count}, disposed=${platform.disposed}, played=${platform.played}');
    platform.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await advance(tester);
    expect(platform.count, 2);
    expect(platform.played, [2]);
    expect(find.text('Tentar novamente'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
    expect(platform.disposed.toSet(), {1, 2});
  });

  testWidgets(
      'changing channel disposes the old player before playing the next',
      (tester) async {
    await tester.pumpWidget(player('https://fixture.invalid/one'));
    await advance(tester);
    await tester.pumpWidget(player('https://fixture.invalid/two'));
    await advance(tester);
    expect(platform.disposed, contains(1), reason: 'Controladores descartados: ${platform.disposed}; reproduzidos: ${platform.played}');
    expect(platform.played, [1, 2]);
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
  });

  testWidgets('initialization timeout shows recovery without claiming playback',
      (tester) async {
    platform.initializeVideo = false;
    await tester.pumpWidget(player('https://fixture.invalid/slow'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await advance(tester);
    expect(find.text('Tentar novamente'), findsOneWidget, reason: 'native created=${platform.count}, disposed=${platform.disposed}, played=${platform.played}');
    expect(platform.played, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
  });
}
