import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';

const first = Channel(name: 'Primeiro', url: 'https://example.test/one');
const second = Channel(name: 'Segundo', url: 'https://example.test/two');

class TestController extends VideoPlayerController {
  TestController({this.fail = false, this.gate}) : super.asset('fixture.mp4');
  final bool fail;
  final Completer<void>? gate;
  int disposals = 0;
  int plays = 0;
  @override
  Future<void> initialize() async {
    await gate?.future;
    if (fail) throw StateError('decoder failed');
    if (disposals == 0) {
      value = const VideoPlayerValue(duration: Duration.zero,
          size: Size(1920, 1080), isInitialized: true);
    }
  }
  @override
  Future<void> play() async { plays++; value = value.copyWith(isPlaying: true); }
  @override
  Future<void> pause() async { value = value.copyWith(isPlaying: false); }
  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}

void main() {
  testWidgets('decoder failure can recover by remote activation without removing the channel', (tester) async {
    final failed = TestController(fail: true);
    final recovered = TestController();
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: first,
      controllerFactory: (_) => attempts++ == 0 ? failed : recovered)));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(failed.disposals, 1);
    expect(recovered.plays, 1);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(recovered.disposals, 1);
  });

  testWidgets('rapid channel switch releases the old controller once and ignores late init', (tester) async {
    final gate = Completer<void>();
    final old = TestController(gate: gate);
    final current = TestController();
    VideoPlayerController factory(Uri uri) => uri.toString() == first.url ? old : current;
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(
      channel: first, controllerFactory: factory)));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(
      channel: second, controllerFactory: factory)));
    await tester.pumpAndSettle();
    expect(old.disposals, 1);
    expect(current.plays, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(old.disposals, 1);
    expect(old.plays, 0);
    expect(find.text('Segundo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(current.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV Back exits fullscreen before leaving the player route', (tester) async {
    final controller = TestController();
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(
      channel: first, initiallyFullscreen: true, controllerFactory: (_) => controller)));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(controller.disposals, 0);
    await tester.pumpWidget(const SizedBox());
    expect(controller.disposals, 1);
  });
}
