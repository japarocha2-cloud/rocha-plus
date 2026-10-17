import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';
import 'package:rocha_plus/src/widgets/player_viewport.dart';

const a = Channel(name: 'Infantil A', url: 'https://example.com/a');
const b = Channel(name: 'Infantil B', url: 'https://example.com/b');
const c = Channel(name: 'Infantil C', url: 'https://example.com/c');

class FakeChannelController extends VideoPlayerController {
  final Completer<void>? gate;
  final Completer<void>? disposalGate;
  final bool fail;
  int disposals = 0;
  int plays = 0;
  FakeChannelController({this.gate, this.disposalGate, this.fail = false}) : super.asset('fake.mp4');
  @override
  Future<void> initialize() async {
    if (gate != null) await gate!.future;
    if (disposals > 0) return;
    if (fail) throw StateError('Unavailable source');
    value = const VideoPlayerValue(duration: Duration(minutes: 1),
      size: Size(1280, 720), isInitialized: true);
  }
  @override
  Future<void> play() async {
    plays++;
    value = value.copyWith(isPlaying: true);
  }
  @override
  Future<void> pause() async { value = value.copyWith(isPlaying: false); }
  @override
  Future<void> dispose() async {
    disposals++;
    if (disposalGate != null) await disposalGate!.future;
    await super.dispose();
  }
}

void main() {
  testWidgets('rapid switches wait for a decoder already being disposed', (tester) async {
    final disposal = Completer<void>();
    final old = FakeChannelController(disposalGate: disposal);
    final created = <String>[];
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: a, lineup: [a, b, c],
      controllerFactory: (uri) {
        created.add(uri.toString());
        return uri.toString() == a.url ? old : FakeChannelController();
      })));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pump();
    expect(created, [a.url], reason: 'Old audio must finish disposing before a new decoder exists');
    disposal.complete();
    await tester.pumpAndSettle();
    expect(created, [a.url, c.url]);
    expect(old.disposals, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('CH switches the actual source, wraps, disposes old decoder and shows the name', (tester) async {
    final created = <Uri>[];
    final controllers = <FakeChannelController>[];
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: b, lineup: [a, b, c],
      controllerFactory: (uri) {
        created.add(uri);
        final controller = FakeChannelController();
        controllers.add(controller);
        return controller;
      })));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pumpAndSettle();
    expect(created.last.toString(), c.url);
    expect(controllers.first.disposals, 1);
    expect(find.text('Infantil C'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pumpAndSettle();
    expect(created.last.toString(), a.url);
    await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
    await tester.pumpAndSettle();
    expect(created.last.toString(), c.url);
    await tester.pumpWidget(const SizedBox());
    expect(controllers.every((controller) => controller.disposals == 1), isTrue);
  });
  testWidgets('a late initialization cannot restart the channel left behind', (tester) async {
    final gate = Completer<void>();
    final old = FakeChannelController(gate: gate);
    final next = FakeChannelController();
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: a, lineup: [a, b],
      controllerFactory: (uri) => uri.toString() == a.url ? old : next)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(old.disposals, 1);
    expect(old.plays, 0);
    expect(next.plays, 1);
    expect(find.text('Infantil B'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('an unavailable channel does not trap remote navigation', (tester) async {
    final created = <Uri>[];
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: a, lineup: [a, b],
      controllerFactory: (uri) {
        created.add(uri);
        return FakeChannelController(fail: uri.toString() == a.url);
      })));
    await tester.pumpAndSettle();
    expect(find.text('Este sinal está indisponível no momento.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pumpAndSettle();
    expect(created.last.toString(), b.url);
    expect(find.text('Este sinal está indisponível no momento.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('changing channel preserves fullscreen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: a, lineup: [a, b],
      controllerFactory: (_) => FakeChannelController())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PlayerViewport));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(PlayerViewport));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Infantil B'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
